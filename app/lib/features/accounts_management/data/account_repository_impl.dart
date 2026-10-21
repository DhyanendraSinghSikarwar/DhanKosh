import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/core/db/tables/accounts.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:parser_core/parser_core.dart';

/// [AccountRepository] over the `accounts` table (FR-13).
///
/// Never writes `transactions`: deleting an account relies on the
/// `ON DELETE SET NULL` foreign key.
class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  static Account _map(AccountRow r) => Account(
        id: r.id,
        bankName: r.bankName,
        last4: r.last4,
        kind: enumFromDb(AccountKind.values, r.kind, AccountKind.account),
        createdAt: r.createdAt,
        nickname: r.nickname,
        colorArgb: r.colorArgb,
        latestBalanceMinor: r.latestBalanceMinor,
        availableLimitMinor: r.availableLimitMinor,
        balanceUpdatedAt: r.balanceUpdatedAt,
        manualBalanceMinor: r.manualBalanceMinor,
        manualBalanceAt: r.manualBalanceAt,
        accountType: enumFromDbOrNull(AccountType.values, r.accountType),
        cardNetwork: enumFromDbOrNull(CardNetwork.values, r.cardNetwork),
        linkedAccountId: r.linkedAccountId,
        hidden: r.hidden,
        usage: enumFromDb(AccountUsage.values, r.usage, AccountUsage.personal),
        mergedIntoId: r.mergedIntoId,
      );

  @override
  Future<Account?> byId(int id) async {
    final r = await (_db.select(_db.accounts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _map(r);
  }

  // FR-13-01..03
  @override
  Future<int?> ensureAccount(
    ParsedTransaction tx, {
    Set<String> phoneLast4s = const {},
  }) async {
    final last4 = tx.accountLast4;
    if (last4 == null || last4.isEmpty) return null;
    final kind = enumToDb(tx.accountKind);
    final existing = await (_db.select(_db.accounts)
          ..where(
            (t) => t.bankName.equals(tx.bankName) & t.last4.equals(last4),
          ))
        .getSingleOrNull();

    final type = tx.isDebitCard
        ? AccountType.debitCard
        : (tx.accountKind == AccountKind.card && tx.availableLimitMinor != null)
            ? AccountType.creditCard
            : null;

    if (existing != null) {
      if (existing.accountType == null && type != null) {
        await (_db.update(_db.accounts)..where((t) => t.id.equals(existing.id)))
            .write(AccountsCompanion(accountType: Value(enumToDb(type))));
      }
      return existing.id;
    }

    if (tx.source == Source.app) {
      // Payment apps never create accounts: unique same-kind bank-prefix match.
      final bank = tx.bankName.toLowerCase();
      final matches = (await (_db.select(_db.accounts)
                ..where((t) => t.last4.equals(last4) & t.kind.equals(kind)))
              .get())
          .where((a) {
        final b = a.bankName.toLowerCase();
        return b.startsWith(bank) || bank.startsWith(b);
      }).toList();
      return matches.length == 1 ? matches.single.id : null;
    }
    if (phoneLast4s.contains(last4)) return null;

    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            bankName: tx.bankName,
            last4: last4,
            kind: kind,
            createdAt: _now(),
            accountType: Value(type == null ? null : enumToDb(type)),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final row = await (_db.select(_db.accounts)
          ..where(
            (t) => t.bankName.equals(tx.bankName) & t.last4.equals(last4),
          ))
        .getSingle();
    return row.id;
  }

  // FR-13-07: older messages never rewind the reported figure.
  @override
  Future<void> updateBalance(
    int accountId, {
    required int at,
    int? balanceMinor,
    int? limitMinor,
  }) async {
    if (balanceMinor == null && limitMinor == null) return;
    await _db.customUpdate(
      'UPDATE accounts SET '
      'latest_balance_minor = COALESCE(?, latest_balance_minor), '
      'available_limit_minor = COALESCE(?, available_limit_minor), '
      'balance_updated_at = ? '
      'WHERE id = ? AND (balance_updated_at IS NULL OR balance_updated_at <= ?)',
      variables: [
        Variable<int>(balanceMinor),
        Variable<int>(limitMinor),
        Variable<int>(at),
        Variable<int>(accountId),
        Variable<int>(at),
      ],
      updates: {_db.accounts},
    );
  }

  // FR-13-05
  @override
  Future<int?> create(NewAccount a) async {
    final exists = await (_db.select(_db.accounts)
          ..where(
            (t) => t.bankName.equals(a.bankName) & t.last4.equals(a.last4),
          ))
        .getSingleOrNull();
    if (exists != null) return null;
    final now = _now();
    return await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            bankName: a.bankName,
            last4: a.last4,
            kind: enumToDb(a.kind),
            createdAt: now,
            accountType: Value(
              a.accountType == null ? null : enumToDb(a.accountType!),
            ),
            cardNetwork: Value(
              a.cardNetwork == null ? null : enumToDb(a.cardNetwork!),
            ),
            usage: Value(enumToDb(a.usage)),
            manualBalanceMinor: Value(a.balanceMinor),
            manualBalanceAt: Value(a.balanceMinor == null ? null : now),
          ),
        );
  }

  Future<void> _patch(int id, AccountsCompanion c) =>
      (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(c);

  @override
  Future<void> rename(int id, String? nickname) {
    final n = nickname?.trim();
    return _patch(
      id,
      AccountsCompanion(
        nickname: Value(n == null || n.isEmpty ? null : n),
      ),
    );
  }

  @override
  Future<void> setType(int id, AccountType? type) => _patch(
        id,
        AccountsCompanion(
          accountType: Value(type == null ? null : enumToDb(type)),
        ),
      );

  @override
  Future<void> setManualBalance(int id, int? balanceMinor, int? at) => _patch(
        id,
        AccountsCompanion(
          manualBalanceMinor: Value(balanceMinor),
          manualBalanceAt: Value(balanceMinor == null ? null : (at ?? _now())),
        ),
      );

  @override
  Future<void> setHidden(int id, {required bool hidden}) =>
      _patch(id, AccountsCompanion(hidden: Value(hidden)));

  @override
  Future<void> setMergedInto(int id, int? targetId) {
    if (targetId == id) {
      throw ArgumentError('Cannot merge an account into itself');
    }
    return _patch(id, AccountsCompanion(mergedIntoId: Value(targetId)));
  }

  // FR-13-11: unmerges children, clears links, FK nulls transactions.accountId.
  @override
  Future<void> delete(int id) => _db.transaction(() async {
        await (_db.update(_db.accounts)
              ..where((t) => t.mergedIntoId.equals(id)))
            .write(const AccountsCompanion(mergedIntoId: Value(null)));
        await (_db.update(_db.accounts)
              ..where((t) => t.linkedAccountId.equals(id)))
            .write(const AccountsCompanion(linkedAccountId: Value(null)));
        await (_db.delete(_db.accounts)..where((t) => t.id.equals(id))).go();
      });

  Stream<List<Account>> _watch(Expression<bool> Function(Accounts t) where) =>
      (_db.select(_db.accounts)
            ..where(where)
            ..orderBy([
              (t) => OrderingTerm.asc(t.bankName),
              (t) => OrderingTerm.asc(t.last4),
            ]))
          .watch()
          .map((rows) => rows.map(_map).toList());

  // FR-13-04: hidden and merged-away accounts leave the lists.
  @override
  Stream<List<Account>> watchVisible() =>
      _watch((t) => t.hidden.equals(false) & t.mergedIntoId.isNull());

  @override
  Stream<List<Account>> watchHidden() => _watch((t) => t.hidden.equals(true));

  // Signed effect of a row on a balance (memory 13 section 3.5).
  static const _effect = '''
CASE t.type
  WHEN 'CREDIT' THEN t.inr_minor
  WHEN 'DEBIT' THEN -t.inr_minor
  WHEN 'INVESTMENT' THEN -t.inr_minor
  WHEN 'TRANSFER' THEN CASE
    WHEN t.account_kind = 'CARD' THEN t.inr_minor
    WHEN EXISTS (SELECT 1 FROM transaction_sources s WHERE s.transaction_id = t.id
                 AND s.source_message_id LIKE 'xfer-out:%') THEN -t.inr_minor
    WHEN EXISTS (SELECT 1 FROM transaction_sources s WHERE s.transaction_id = t.id
                 AND s.source_message_id LIKE 'xfer-in:%') THEN t.inr_minor
    WHEN t.note LIKE 'Credit card bill%' THEN -t.inr_minor
    ELSE 0 END
  ELSE 0 END''';

  @override
  Stream<List<AccountWithActivity>> watchWithActivity({
    required int monthStartMs,
    required int monthEndMs,
  }) =>
      _db
          .customSelect(
            'SELECT 1',
            readsFrom: {_db.accounts, _db.transactions, _db.transactionSources},
          )
          .watch()
          .asyncMap((_) => _activity(monthStartMs, monthEndMs));

  Future<List<AccountWithActivity>> _activity(int from, int to) async {
    final all = (await _db.select(_db.accounts).get()).map(_map).toList();
    final out = <AccountWithActivity>[];
    for (final a in all.where((a) => !a.hidden && a.mergedIntoId == null)) {
      final merged = {
        a.id,
        ...all.where((c) => c.mergedIntoId == a.id).map((c) => c.id),
      };
      final members = {
        ...merged,
        ...all
            .where(
              (c) =>
                  c.linkedAccountId != null &&
                  merged.contains(c.linkedAccountId),
            )
            .map((c) => c.id),
      };
      final row = await _db.customSelect(
        'SELECT '
        'COALESCE(SUM(CASE WHEN t.timestamp > ? THEN $_effect END), 0) AS m, '
        'COALESCE(SUM(CASE WHEN t.timestamp > ? THEN $_effect END), 0) AS r, '
        "COALESCE(SUM(CASE WHEN t.type IN ('DEBIT','INVESTMENT') "
        'AND t.timestamp >= ? AND t.timestamp < ? THEN t.inr_minor END), 0) AS s '
        'FROM transactions t '
        'WHERE t.account_id IN (${members.join(',')}) '
        'AND t.needs_review = 0 AND t.inr_minor IS NOT NULL',
        variables: [
          Variable<int>(a.manualBalanceAt),
          Variable<int>(a.balanceUpdatedAt),
          Variable<int>(from),
          Variable<int>(to),
        ],
        readsFrom: {_db.transactions, _db.transactionSources},
      ).getSingle();
      final count = await _db.customSelect(
        'SELECT COUNT(*) AS c FROM transactions '
        'WHERE account_id IN (${merged.join(',')})',
        readsFrom: {_db.transactions},
      ).getSingle();
      final nonLiquid = a.accountType != null && !a.accountType!.liquid;
      out.add(
        AccountWithActivity(
          account: a,
          changeSinceManual: row.read<int>('m'),
          changeSinceReported: nonLiquid ? 0 : row.read<int>('r'),
          monthSpent: row.read<int>('s'),
          transactionCount: count.read<int>('c'),
        ),
      );
    }
    return out;
  }
}
