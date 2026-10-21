import 'dart:math';

import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/core/db/tables/transactions.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/categorization/domain/category_repository.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/dedup_review/domain/dedup_policy.dart';
import 'package:hisaab/features/dedup_review/domain/merge_rules.dart';
import 'package:hisaab/features/transactions_ledger/data/transaction_mappers.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart';

/// The single ledger write path (FR-08-17, FR-07-07).
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(
    this._db, {
    required AccountRepository accounts,
    required CategoryRepository categories,
    DedupPolicy policy = const DedupPolicy(),
    int Function()? now,
  })  : _accounts = accounts,
        _categories = categories,
        _policy = policy,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const rawTextCap = 20000;
  static const tombstoneChunk = 900;

  final AppDatabase _db;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final DedupPolicy _policy;
  final int Function() _now;

  // ---------------------------------------------------------------- ingest

  @override
  Future<IngestResult> ingest(IngestItem item) async =>
      (await ingestBatch([item])).results.single;

  // FR-07-07, FR-08-17: one DB transaction per batch; throws roll back all.
  @override
  Future<IngestReport> ingestBatch(List<IngestItem> items) =>
      _db.transaction(() async {
        final rules = await _categories.loadRuleSet();
        final results = <IngestResult>[];
        for (final item in items) {
          results.add(await _ingestOne(item, rules));
        }
        return IngestReport(results);
      });

  Future<IngestResult> _ingestOne(IngestItem item, RuleSet rules) async {
    final src = enumToDb(item.parsed.source);

    // FR-07-07 step 3 / FR-08-22: processed ids and tombstones.
    final processed = await (_db.select(_db.transactionSources)
          ..where(
            (s) =>
                s.source.equals(src) &
                s.sourceMessageId.equals(item.sourceMessageId),
          ))
        .getSingleOrNull();
    if (processed != null) {
      return const IngestResult(
        IngestOutcome.skipped,
        reason: 'already_processed',
      );
    }
    final tomb = await (_db.select(_db.deletedMessages)
          ..where(
            (d) =>
                d.source.equals(src) & d.messageId.equals(item.sourceMessageId),
          ))
        .getSingleOrNull();
    if (tomb != null) {
      return const IngestResult(IngestOutcome.skipped, reason: 'deleted');
    }

    // FR-09-10: merchant rule (never for transfers).
    var p = item.parsed;
    final rule = rules.ruleFor(
      merchant: p.merchant,
      upiId: p.upiId,
      type: p.type,
    );
    if (rule != null) {
      p = withCategory(
        p,
        rule.customCategoryId != null ? Category.other : rule.category,
      );
    }

    final candidates = await _candidates(p);
    var decision = await _policy.decide(p, candidates);
    final accountId = item.accountId ??
        await _accounts.ensureAccount(p, phoneLast4s: item.phoneLast4s);

    // Unique-hash race: a stored row with this hash absorbs the message.
    if (decision is DedupNew) {
      final same = candidates
          .where((c) => c.transactionHash == p.transactionHash)
          .toList();
      if (same.isNotEmpty) {
        decision = DedupDuplicate(same.first.id, DuplicateReason.hash);
      }
    }

    int txId;
    IngestOutcome outcome;
    String? reason;
    switch (decision) {
      case DedupDuplicate(:final existingId):
        txId = existingId;
        outcome = IngestOutcome.merged;
        await _merge(
          candidates.firstWhere((c) => c.id == existingId),
          p,
          accountId,
          rule,
        );
      case DedupPossible(:final existingId, :final reasonText):
        outcome = IngestOutcome.flagged;
        reason = reasonText;
        txId = await _insert(
          p,
          item,
          accountId,
          hash: '${p.transactionHash}#$src:${item.sourceMessageId}',
          flagged: (existingId, reasonText),
          rule: rule,
        );
      case DedupNew():
        outcome = IngestOutcome.inserted;
        txId = await _insert(
          p,
          item,
          accountId,
          hash: p.transactionHash,
          rule: rule,
        );
    }

    // FR-07-07 step 8: always record the source so a rescan is idempotent.
    final raw = item.rawText;
    await _db.into(_db.transactionSources).insert(
          TransactionSourcesCompanion.insert(
            transactionId: txId,
            source: src,
            sourceMessageId: item.sourceMessageId,
            sender: p.sender,
            parsedHash: p.transactionHash,
            rawText: Value(
              raw != null && raw.length > rawTextCap
                  ? raw.substring(0, rawTextCap)
                  : raw,
            ),
            receivedAt: p.messageTimestamp,
            subject: Value(item.subject),
          ),
        );

    // Step 9: flagged rows stay out of balances.
    if (outcome != IngestOutcome.flagged) {
      final row = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      await _applyBalance(p, row.accountId ?? accountId);
    }
    return IngestResult(outcome, transactionId: txId, reason: reason);
  }

  /// Debit-card messages state the linked bank account's balance; credit
  /// cards state a limit, never a balance (memory 13 3.5).
  Future<void> _applyBalance(ParsedTransaction p, int? accountId) async {
    if (accountId == null) return;
    var target = accountId;
    if (p.isDebitCard) {
      final linked = (await _accounts.byId(accountId))?.linkedAccountId;
      if (linked != null) target = linked;
    }
    final isCredit = p.accountKind == AccountKind.card && !p.isDebitCard;
    await _accounts.updateBalance(
      target,
      balanceMinor: isCredit ? null : p.balanceMinor,
      limitMinor: p.availableLimitMinor,
      at: p.transactionTime,
    );
  }

  Future<List<DedupCandidate>> _candidates(ParsedTransaction p) async {
    const span = DedupPolicy.statementWindowMillis;
    final ref = p.referenceNumber;
    final conds = <Expression<bool>>[
      _db.transactions.transactionHash.equals(p.transactionHash),
      _db.transactions.id.isInQuery(
        _db.selectOnly(_db.transactionSources)
          ..addColumns([_db.transactionSources.transactionId])
          ..where(_db.transactionSources.parsedHash.equals(p.transactionHash)),
      ),
      _db.transactions.timestamp.isBetweenValues(
            p.transactionTime - span,
            p.transactionTime + span,
          ) &
          _db.transactions.amountMinor.isBetweenValues(
            max(0, p.amountMinor - 99),
            p.amountMinor + 99,
          ),
      if (ref != null && ref.isNotEmpty)
        _db.transactions.referenceNumber.equals(ref),
    ];
    final rows = await (_db.select(_db.transactions)
          ..where(
            (t) => t.needsReview.equals(false) & conds.reduce((a, b) => a | b),
          ))
        .get();
    if (rows.isEmpty) return const [];
    final srcs = await (_db.select(_db.transactionSources)
          ..where((s) => s.transactionId.isIn(rows.map((r) => r.id))))
        .get();
    return [
      for (final r in rows)
        toCandidate(r, srcs.where((s) => s.transactionId == r.id).toList()),
    ];
  }

  Future<int> _insert(
    ParsedTransaction p,
    IngestItem item,
    int? accountId, {
    required String hash,
    required MerchantRule? rule,
    (int, String)? flagged,
  }) {
    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amountMinor: p.amountMinor,
            currency: p.currency,
            type: enumToDb(p.type),
            bankName: p.bankName,
            accountLast4: Value(p.accountLast4),
            accountKind: enumToDb(p.accountKind),
            accountId: Value(accountId),
            merchant: Value(p.merchant),
            upiId: Value(p.upiId),
            referenceNumber: Value(p.referenceNumber),
            channel: enumToDb(p.channel),
            balanceMinor: Value(p.balanceMinor),
            availableLimitMinor: Value(p.availableLimitMinor),
            timestamp: p.transactionTime,
            hasExplicitTime: p.hasExplicitTime,
            category: enumToDb(p.category),
            transactionHash: hash,
            confidence: p.confidence,
            needsReview: Value(flagged != null),
            duplicateOfId: Value(flagged?.$1),
            reviewReason: Value(flagged?.$2),
            note: Value(item.note),
            createdAt: _now(),
            subcategory: Value(rule?.subcategory),
            customCategoryId: Value(rule?.customCategoryId),
            // Forex conversion is not wired yet: INR rows only (FR-08-18).
            inrMinor: Value(p.currency == 'INR' ? p.amountMinor : null),
          ),
        );
  }

  // FR-07-09: keep stored values, fill gaps from the message.
  Future<void> _merge(
    DedupCandidate c,
    ParsedTransaction p,
    int? accountId,
    MerchantRule? rule,
  ) async {
    final m = mergeInto(c, p);
    final row = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(c.id)))
        .getSingle();
    final adopt =
        p.source != Source.app && accountId != null && row.accountId == null;
    final keepsOwn = row.subcategory == null &&
        row.customCategoryId == null &&
        rule != null &&
        m.category == rule.category;
    await (_db.update(_db.transactions)..where((t) => t.id.equals(c.id))).write(
      TransactionsCompanion(
        amountMinor: Value(m.amountMinor),
        merchant: Value(m.merchant),
        upiId: Value(m.upiId),
        referenceNumber: Value(m.referenceNumber),
        balanceMinor: Value(m.balanceMinor),
        availableLimitMinor: Value(m.availableLimitMinor),
        accountLast4: Value(m.accountLast4),
        type: Value(enumToDb(m.type)),
        category: Value(enumToDb(m.category)),
        timestamp: Value(m.timestamp),
        hasExplicitTime: Value(m.hasExplicitTime),
        confidence: Value(m.confidence),
        inrMinor: Value(
          row.currency == 'INR' ? m.amountMinor : row.inrMinor,
        ),
        accountId: adopt ? Value(accountId) : const Value.absent(),
        subcategory: keepsOwn ? Value(rule.subcategory) : const Value.absent(),
        customCategoryId:
            keepsOwn ? Value(rule.customCategoryId) : const Value.absent(),
      ),
    );
  }

  @override
  Future<IngestResult> addManual({
    required int amountMinor,
    required TransactionType type,
    required int timestamp,
    int? accountId,
    String? merchant,
    Category category = Category.other,
    String? reference,
    String? note,
  }) async {
    final account = accountId == null ? null : await _accounts.byId(accountId);
    final id =
        'manual:$timestamp-${Random().nextInt(1 << 31).toRadixString(36)}';
    final bank = account?.bankName ?? 'Cash / other';
    return await ingest(
      IngestItem(
        parsed: ParsedTransaction(
          amountMinor: amountMinor,
          currency: 'INR',
          type: type,
          bankName: bank,
          accountLast4: account?.last4,
          accountKind: account?.kind ?? AccountKind.account,
          merchant: merchant,
          upiId: null,
          referenceNumber: reference,
          channel: Channel.other,
          balanceMinor: null,
          availableLimitMinor: null,
          transactionTime: timestamp,
          hasExplicitTime: true,
          category: category,
          source: Source.manual,
          sender: bank,
          messageTimestamp: _now(),
          confidence: 1,
          transactionHash: id,
        ),
        sourceMessageId: id,
        accountId: accountId,
        note: note,
      ),
    );
  }

  // --------------------------------------------------------------- edits

  Future<void> _patch(int id, TransactionsCompanion c) =>
      (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(c);

  // FR-09-05/06/07
  @override
  Future<void> setCategory(
    List<int> ids,
    Category category, {
    int? customCategoryId,
    String? subcategory,
  }) =>
      _db.transaction(() async {
        final stored = customCategoryId != null ? Category.other : category;
        final keys = <String>{};
        for (final id in ids) {
          final row = await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(id)))
              .getSingleOrNull();
          if (row == null) continue;
          await _patch(
            id,
            TransactionsCompanion(
              category: Value(enumToDb(stored)),
              subcategory: Value(subcategory),
              customCategoryId: Value(customCategoryId),
            ),
          );
          if (row.type != 'TRANSFER' && customCategoryId == null) {
            final k = MerchantRule.keyOf(row.merchant, row.upiId);
            if (k != null) keys.add(k);
          }
        }
        for (final k in keys) {
          if (await _categories.learn(k, category, at: _now())) {
            await _db.customUpdate(
              'UPDATE transactions SET category = ? '
              "WHERE category = 'OTHER' AND type IN ('DEBIT','CREDIT','INVESTMENT') "
              'AND (LOWER(TRIM(merchant)) = ? '
              'OR (merchant IS NULL AND LOWER(TRIM(upi_id)) = ?))',
              variables: [
                Variable<String>(enumToDb(category)),
                Variable<String>(k),
                Variable<String>(k),
              ],
              updates: {_db.transactions},
            );
          }
        }
      });

  @override
  Future<void> setSubcategory(int id, String? subcategory) =>
      _patch(id, TransactionsCompanion(subcategory: Value(subcategory)));

  @override
  Future<void> setNote(int id, String? note) {
    final n = note?.trim();
    return _patch(
      id,
      TransactionsCompanion(note: Value(n == null || n.isEmpty ? null : n)),
    );
  }

  @override
  Future<void> setAccount(int id, int? accountId) async {
    final a = accountId == null ? null : await _accounts.byId(accountId);
    await _patch(
      id,
      TransactionsCompanion(
        accountId: Value(accountId),
        accountLast4: a == null ? const Value.absent() : Value(a.last4),
      ),
    );
  }

  // FR-08-09 / FR-08-22: tombstones for every source, chunks of 900.
  @override
  Future<int> deleteTransactions(List<int> ids) => _db.transaction(() async {
        var deleted = 0;
        for (var i = 0; i < ids.length; i += tombstoneChunk) {
          final chunk = ids.sublist(i, min(i + tombstoneChunk, ids.length));
          final srcs = await (_db.select(_db.transactionSources)
                ..where((s) => s.transactionId.isIn(chunk)))
              .get();
          final at = _now();
          await _db.batch((b) {
            b.insertAll(
              _db.deletedMessages,
              [
                for (final s in srcs)
                  DeletedMessagesCompanion.insert(
                    source: s.source,
                    messageId: s.sourceMessageId,
                    deletedAt: at,
                  ),
              ],
              mode: InsertMode.insertOrIgnore,
            );
          });
          deleted += await (_db.delete(_db.transactions)
                ..where((t) => t.id.isIn(chunk)))
              .go();
        }
        return deleted;
      });

  // FR-07-12
  @override
  Future<void> mergeFlagged(int id) => _db.transaction(() async {
        final f = await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (f == null) return;
        final target = f.duplicateOfId == null
            ? null
            : await (_db.select(_db.transactions)
                  ..where((t) => t.id.equals(f.duplicateOfId!)))
                .getSingleOrNull();
        if (target == null) {
          await keepSeparate(id);
          return;
        }
        final tLast4 = target.accountLast4;
        await _patch(
          target.id,
          TransactionsCompanion(
            merchant: Value(
              isWeakMerchant(target.merchant) && !isWeakMerchant(f.merchant)
                  ? f.merchant
                  : (target.merchant ?? f.merchant),
            ),
            upiId: Value(target.upiId ?? f.upiId),
            referenceNumber: Value(target.referenceNumber ?? f.referenceNumber),
            balanceMinor: Value(target.balanceMinor ?? f.balanceMinor),
            availableLimitMinor:
                Value(target.availableLimitMinor ?? f.availableLimitMinor),
            accountId: Value(target.accountId ?? f.accountId),
            accountLast4: Value(
              tLast4 == null || ((f.accountLast4?.length ?? 0) > tLast4.length)
                  ? (f.accountLast4 ?? tLast4)
                  : tLast4,
            ),
            note: Value(target.note ?? f.note),
            confidence: Value(max(target.confidence, f.confidence)),
          ),
        );
        await (_db.update(_db.transactionSources)
              ..where((s) => s.transactionId.equals(id)))
            .write(
          TransactionSourcesCompanion(transactionId: Value(target.id)),
        );
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(id)))
            .go();
      });

  @override
  Future<void> keepSeparate(int id) => _patch(
        id,
        const TransactionsCompanion(
          needsReview: Value(false),
          duplicateOfId: Value(null),
          reviewReason: Value(null),
        ),
      );

  // ------------------------------------------------------- rule application

  /// WHERE clause + variables for a rule over past non-transfer rows.
  (String, List<Variable<Object>>) _ruleWhere(MerchantRule r) {
    if (r.matchType == RuleMatch.exact) {
      return (
        "type != 'TRANSFER' AND (LOWER(TRIM(merchant)) = ? OR LOWER(TRIM(upi_id)) = ?)",
        [Variable<String>(r.merchantKey), Variable<String>(r.merchantKey)],
      );
    }
    final esc = r.merchantKey
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return (
      "type != 'TRANSFER' AND LOWER(COALESCE(merchant,'') || ' ' || "
          r"COALESCE(upi_id,'')) LIKE ? ESCAPE '\'",
      [Variable<String>('%$esc%')],
    );
  }

  @override
  Future<int> applyRuleToPast(MerchantRule r) {
    final (where, vars) = _ruleWhere(r);
    final category = r.customCategoryId != null ? Category.other : r.category;
    return _db.customUpdate(
      'UPDATE transactions SET category = ?, subcategory = ?, '
      'custom_category_id = ? WHERE $where',
      variables: [
        Variable<String>(enumToDb(category)),
        Variable<String>(r.subcategory),
        Variable<int>(r.customCategoryId),
        ...vars,
      ],
      updates: {_db.transactions},
    );
  }

  @override
  Future<int> countRuleMatches(MerchantRule r) async {
    final (where, vars) = _ruleWhere(r);
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE $where',
      variables: vars,
      readsFrom: {_db.transactions},
    ).getSingle();
    return row.read<int>('c');
  }

  // ------------------------------------------------------------------ reads

  @override
  Future<LedgerTx?> byId(int id) async {
    final r = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : toLedgerTx(r);
  }

  @override
  Future<List<TxSourceRow>> sourcesOf(int id) async =>
      (await (_db.select(_db.transactionSources)
                ..where((s) => s.transactionId.equals(id))
                ..orderBy([(s) => OrderingTerm.asc(s.receivedAt)]))
              .get())
          .map(toSourceRow)
          .toList();

  static String _accountScope(int id) =>
      'SELECT id FROM accounts WHERE id = $id OR merged_into_id = $id';

  @override
  Future<List<int>> idsForAccount(int accountId) async {
    final rows = await _db.customSelect(
      'SELECT id FROM transactions WHERE account_id IN (${_accountScope(accountId)})',
      readsFrom: {_db.transactions, _db.accounts},
    ).get();
    return [for (final r in rows) r.read<int>('id')];
  }

  Expression<bool> _where(Transactions t, LedgerFilter f) {
    final c = <Expression<bool>>[
      t.needsReview.equals(f.kind == TxKind.review),
      switch (f.kind) {
        TxKind.income => t.type.equals('CREDIT'),
        TxKind.spends => t.type.equals('DEBIT'),
        TxKind.investments => t.type.equals('INVESTMENT'),
        TxKind.transfers => t.type.equals('TRANSFER'),
        _ => const Constant(true),
      },
      if (f.fromMs != null) t.timestamp.isBiggerOrEqualValue(f.fromMs!),
      if (f.toMs != null) t.timestamp.isSmallerThanValue(f.toMs!),
      if (f.accountId != null)
        CustomExpression<bool>(
          'transactions.account_id IN (${_accountScope(f.accountId!)})',
        ),
      if (f.category != null) t.category.equals(enumToDb(f.category!)),
      if (f.sources.isNotEmpty)
        t.id.isInQuery(
          _db.selectOnly(_db.transactionSources)
            ..addColumns([_db.transactionSources.transactionId])
            ..where(
              _db.transactionSources.source.isIn(f.sources.map(enumToDb)),
            ),
        ),
      if (f.banks.isNotEmpty) t.bankName.isIn(f.banks),
    ];
    final q = f.query.trim();
    if (q.isNotEmpty) {
      final labels = [
        for (final cat in Category.values)
          if (cat.label.toLowerCase().contains(q.toLowerCase())) enumToDb(cat),
      ];
      final digits = q.replaceAll(',', '');
      c.add(
        t.merchant.contains(q) |
            t.bankName.contains(q) |
            t.note.contains(q) |
            t.referenceNumber.contains(q) |
            t.upiId.contains(q) |
            (labels.isEmpty ? const Constant(false) : t.category.isIn(labels)) |
            (RegExp(r'^\d+$').hasMatch(digits)
                ? CustomExpression<bool>(
                    "CAST(transactions.amount_minor / 100 AS TEXT) LIKE '$digits%'",
                  )
                : const Constant(false)),
      );
    }
    return c.reduce((a, b) => a & b);
  }

  @override
  Stream<List<LedgerTx>> watch(LedgerFilter filter, {int? limit}) {
    final q = _db.select(_db.transactions)
      ..where((t) => _where(t, filter))
      ..orderBy([
        (t) => OrderingTerm.desc(t.timestamp),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null) q.limit(limit);
    return q.watch().map((rows) => rows.map(toLedgerTx).toList());
  }

  @override
  Stream<List<LedgerTx>> watchRecent(int n) =>
      watch(const LedgerFilter(), limit: n);

  // Spend/income per `MonthSpend` (memory 08 3.7): transfers and review rows out.
  @override
  Stream<PeriodTotals> watchTotals({
    required int fromMs,
    required int toMs,
    int? accountId,
  }) =>
      _db
          .customSelect(
            'SELECT '
            "COALESCE(SUM(CASE WHEN type='DEBIT' AND category!='TRANSFER' THEN inr_minor END),0) AS spent, "
            "COALESCE(SUM(CASE WHEN type='INVESTMENT' THEN inr_minor END),0) AS invested, "
            "COALESCE(SUM(CASE WHEN type='CREDIT' AND category NOT IN ('TRANSFER','REFUND') THEN inr_minor END),0) AS income, "
            "COALESCE(SUM(CASE WHEN type='CREDIT' AND category='REFUND' THEN inr_minor END),0) AS refund, "
            'COUNT(*) AS n FROM transactions '
            'WHERE needs_review = 0 AND inr_minor IS NOT NULL '
            'AND timestamp >= ? AND timestamp < ?'
            '${accountId == null ? '' : ' AND account_id IN (${_accountScope(accountId)})'}',
            variables: [Variable<int>(fromMs), Variable<int>(toMs)],
            readsFrom: {_db.transactions, _db.accounts},
          )
          .watchSingle()
          .map(
            (r) => PeriodTotals(
              spentMinor: r.read<int>('spent'),
              investedMinor: r.read<int>('invested'),
              incomeMinor: r.read<int>('income'),
              refundMinor: r.read<int>('refund'),
              count: r.read<int>('n'),
            ),
          );

  @override
  Stream<int> watchReviewCount() => _db
      .customSelect(
        'SELECT COUNT(*) AS c FROM transactions WHERE needs_review = 1',
        readsFrom: {_db.transactions},
      )
      .watchSingle()
      .map((r) => r.read<int>('c'));

  @override
  Stream<List<ReviewPair>> watchReviewPairs() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.transactions},
      )
      .watch()
      .asyncMap((_) async {
        final flagged = await (_db.select(_db.transactions)
              ..where((t) => t.needsReview.equals(true))
              ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
            .get();
        final out = <ReviewPair>[];
        for (final f in flagged) {
          final target =
              f.duplicateOfId == null ? null : await byId(f.duplicateOfId!);
          out.add(ReviewPair(toLedgerTx(f), target));
        }
        return out;
      });
}
