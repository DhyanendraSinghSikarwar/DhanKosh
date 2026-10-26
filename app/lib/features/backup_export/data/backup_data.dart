import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart'
    show weeklySummaryKey;
import 'package:hisaab/features/backup_export/domain/full_backup.dart';
import 'package:hisaab/features/categorization/domain/category_repository.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_repository.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';
import 'package:hisaab/features/forex_rates/domain/forex_repository.dart';
import 'package:hisaab/features/loans/domain/loan_account_repository.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_repository.dart';
import 'package:hisaab/features/security_privacy/domain/security_settings.dart';
import 'package:hisaab/features/settings_data_sources/domain/data_reset_repository.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart' hide HoldingKind, HoldingSnapshot;

/// JSON format name inside the encrypted container (FR-24-18).
const backupFormat = 'dhankosh-backup';

/// JSON schema version (FR-24-18); the container has its own version byte.
const backupSchema = 1;

/// Repositories the full backup reads and restores through (FR-24-25).
class BackupDeps {
  /// Bundles the repositories.
  const BackupDeps({
    required this.txs,
    required this.accounts,
    required this.loans,
    required this.categories,
    required this.budgets,
    required this.recurring,
    required this.holdings,
    required this.cards,
    required this.cardPaid,
    required this.loanLinks,
    required this.forex,
    required this.settings,
    required this.reset,
  });

  final TransactionRepository txs;
  final AccountRepository accounts;
  final LoanAccountRepository loans;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  final RecurringRepository recurring;
  final HoldingRepository holdings;
  final CardDueRepository cards;
  final CardPaidStore cardPaid;
  final LoanLinkRepository loanLinks;
  final ForexRepository forex;
  final SettingsRepository settings;
  final DataResetRepository reset;
}

/// Settings carried in a backup: preferences only, no lock state, secrets,
/// identity or passwords (FR-24-19).
final backupSettings = <SettingKey<Object>>[
  SettingKeys.hideAmounts,
  SettingKeys.historyDays,
  SettingKeys.budgetAlertPercent,
  SettingKeys.transactionNotifications,
  SettingKeys.cardDueReminders,
  SettingKeys.checkUpdates,
  SecuritySettings.autoLockMinutes,
  SecuritySettings.blockScreenshots,
  weeklySummaryKey,
];

String _acct(String bank, String last4) => '$bank|$last4';

String _hashOf(String h) {
  final i = h.indexOf('#');
  return i < 0 ? h : h.substring(0, i);
}

/// Builds and restores the structured backup (FR-24-17..27).
class BackupData {
  /// Creates the service.
  const BackupData(this._d);

  final BackupDeps _d;

  Future<List<LedgerTx>> _allTx() async {
    final main = await _d.txs.watch(const LedgerFilter()).first;
    final review =
        await _d.txs.watch(const LedgerFilter(kind: TxKind.review)).first;
    final byId = {
      for (final t in [...main, ...review]) t.id: t,
    };
    return byId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<List<Account>> _allAccounts() async => [
        ...await _d.accounts.watchVisible().first,
        ...await _d.accounts.watchHidden().first,
      ];

  // ---------------------------------------------------------------- collect

  /// The backup document (FR-24-18).
  Future<Map<String, Object?>> collect({required int now}) async {
    final accounts = await _allAccounts();
    final accKey = {for (final a in accounts) a.id: _acct(a.bankName, a.last4)};
    final customs = await _d.categories.watchCustomCategories().first;
    final customName = {for (final c in customs) c.id: c.name};

    final txs = <Map<String, Object?>>[];
    final txHashById = <int, String>{};
    for (final t in await _allTx()) {
      final sources = await _d.txs.sourcesOf(t.id);
      txHashById[t.id] = t.transactionHash;
      txs.add({
        'hash': _hashOf(t.transactionHash),
        'amount': t.amountMinor,
        'currency': t.currency,
        'type': enumToDb(t.type),
        'bank': t.bankName,
        'last4': t.accountLast4,
        'kind': enumToDb(t.accountKind),
        'merchant': t.merchant,
        'upi': t.upiId,
        'ref': t.referenceNumber,
        'channel': enumToDb(t.channel),
        'balance': t.balanceMinor,
        'limit': t.availableLimitMinor,
        'ts': t.timestamp,
        'explicitTime': t.hasExplicitTime,
        'category': enumToDb(t.category),
        'sub': t.subcategory,
        'custom':
            t.customCategoryId == null ? null : customName[t.customCategoryId],
        'confidence': t.confidence,
        'review': t.needsReview,
        'note': t.note,
        'inr': t.inrMinor,
        'sources': [
          for (final s in sources)
            {
              'source': enumToDb(s.source),
              'id': s.sourceMessageId,
              'sender': s.sender,
              'hash': s.parsedHash,
              'raw': s.rawText,
              'at': s.receivedAt,
              'subject': s.subject,
            },
        ],
      });
    }

    final subs = <Map<String, Object?>>[];
    for (final parent in [
      ...Category.values.map(enumToDb),
      ...customs.map((c) => 'custom:${c.id}'),
    ]) {
      for (final s in await _d.categories.watchSubcategories(parent).first) {
        subs.add({
          'parent': parent.startsWith('custom:')
              ? 'custom:${customName[int.tryParse(parent.substring(7))] ?? ''}'
              : parent,
          'name': s.name,
          'icon': s.icon,
        });
      }
    }

    final book = await _d.loans.watch().first;
    final links = await _d.loanLinks.read();
    final paid = await _d.cardPaid.watchPaid().first;
    final overrides = await _d.cards.watchOverrides().first;
    final settings = <String, Object?>{};
    for (final k in backupSettings) {
      final v = await _d.settings.read(k);
      if (v is bool || v is int || v is String) settings[k.name] = v;
    }

    return {
      'format': backupFormat,
      'schema': backupSchema,
      'createdAt': now,
      'accounts': [
        for (final a in accounts)
          {
            'bank': a.bankName,
            'last4': a.last4,
            'kind': enumToDb(a.kind),
            'nickname': a.nickname,
            'color': a.colorArgb,
            'type': a.accountType == null ? null : enumToDb(a.accountType!),
            'network': a.cardNetwork == null ? null : enumToDb(a.cardNetwork!),
            'usage': enumToDb(a.usage),
            'manual': a.manualBalanceMinor,
            'manualAt': a.manualBalanceAt,
            'hidden': a.hidden,
          },
      ],
      'loans': [
        for (final l in [...book.loans, ...book.merged])
          if (l.principalMinor != null &&
              l.rateBps != null &&
              l.tenureMonths != null)
            {
              'bank': l.bankName,
              'last4': l.last4,
              'principal': l.principalMinor,
              'rate': l.rateBps,
              'tenure': l.tenureMonths,
              'startDay': l.startDay,
              'outstanding': l.currentBalanceMinor,
            },
      ],
      'transactions': txs,
      'rules': [
        for (final r in await _d.categories.watchRules().first)
          {
            'key': r.merchantKey,
            'category': enumToDb(r.category),
            'at': r.updatedAt,
            'match': enumToDb(r.matchType),
            'sub': r.subcategory,
            'custom': r.customCategoryId == null
                ? null
                : customName[r.customCategoryId],
            'manual': r.manual,
          },
      ],
      'customCategories': [
        for (final c in customs)
          {'name': c.name, 'icon': c.icon, 'color': c.colorArgb},
      ],
      'customSubcategories': subs,
      'budgets': [
        for (final b in await _d.budgets.all())
          {'category': enumToDb(b.category), 'limit': b.monthlyLimitMinor},
      ],
      'recurring': [
        for (final r in await _d.recurring.all())
          {
            'name': r.name,
            'amount': r.amountMinor,
            'income': r.income,
            'freq': enumToDb(r.frequency),
            'day': r.dayOfMonth,
            'month': r.month,
            'category': enumToDb(r.category),
            'account': r.accountId == null ? null : accKey[r.accountId],
          },
      ],
      'holdings': [
        for (final h in await _d.holdings.list())
          {
            'kind': enumToDb(h.kind),
            'name': h.name,
            'identifier': h.identifier,
            'units': h.units,
            'value': h.valueMinor,
            'invested': h.investedMinor,
            'asOf': h.asOf,
            'source': enumToDb(h.source),
            'note': h.note,
          },
      ],
      'cardOverrides': [
        for (final o in overrides.values)
          {
            'cardKey': o.cardKey,
            'setAt': o.setAt,
            'billed': o.billedMinor,
            'minDue': o.minDueMinor,
            'dueDay': o.dueEpochDay,
            'unbilled': o.unbilledMinor,
            'outstanding': o.outstandingMinor,
          },
      ],
      'cardPaid': [
        for (final p in paid)
          if (accKey[int.tryParse(p.split('|').first)] != null)
            {
              'account': accKey[int.parse(p.split('|').first)],
              'day': int.tryParse(p.split('|').last),
            },
      ],
      'loanLinks': {
        'tx': [
          for (final e in links.tx.entries)
            if (txHashById[e.key] != null && accKey[e.value] != null)
              {'hash': _hashOf(txHashById[e.key]!), 'loan': accKey[e.value]},
        ],
        'payee': [
          for (final e in links.payee.entries)
            if (accKey[e.value] != null)
              {'payee': e.key, 'loan': accKey[e.value]},
        ],
        'manual': links.manualPayees.toList(),
        'dismissed': links.dismissed.toList(),
      },
      'forex': [
        for (final r in await _d.forex.rates())
          {'currency': r.currency, 'day': r.day, 'rate': r.inrPerUnit},
      ],
      'settings': settings,
    };
  }

  /// Counts per section of a decoded document (FR-24-23).
  static BackupCounts summarize(Map<String, Object?> doc) {
    int n(String k) => (doc[k] as List?)?.length ?? 0;
    return BackupCounts({
      'transactions': n('transactions'),
      'accounts': n('accounts'),
      'rules': n('rules'),
      'categories': n('customCategories') + n('customSubcategories'),
      'budgets': n('budgets'),
      'recurring items': n('recurring'),
      'holdings': n('holdings'),
      'card entries': n('cardOverrides') + n('cardPaid'),
      'loans': n('loans'),
      'forex rates': n('forex'),
    });
  }

  /// Checks [doc] is a readable backup (FR-24-21).
  static void validate(Map<String, Object?> doc) {
    if (doc['format'] != backupFormat) {
      throw const FormatException('Not a DhanKosh backup');
    }
    final v = doc['schema'];
    if (v is! int || v > backupSchema) {
      throw const FormatException('Backup is from a newer app version');
    }
  }

  // ---------------------------------------------------------------- restore

  /// Restores [doc] through the repositories (FR-24-25..27). With [replace]
  /// the existing data is erased first; otherwise it is merged, never
  /// overwritten.
  Future<BackupCounts> restore(
    Map<String, Object?> doc, {
    bool replace = false,
  }) async {
    validate(doc);
    if (replace) await _d.reset.eraseAll(keepSettings: true);
    final added = <String, int>{};
    void bump(String k, [int n = 1]) => added[k] = (added[k] ?? 0) + n;

    List<Map<String, Object?>> list(String k) => [
          for (final e in (doc[k] as List?) ?? const <Object?>[])
            (e! as Map).cast<String, Object?>(),
        ];

    // Custom categories first: rules and rows refer to them by name.
    final customId = <String, int>{
      for (final c in await _d.categories.watchCustomCategories().first)
        c.name: c.id,
    };
    for (final c in list('customCategories')) {
      final name = c['name']! as String;
      if (customId.containsKey(name)) continue;
      customId[name] = await _d.categories.addCustomCategory(
        name: name,
        icon: c['icon']! as String,
        colorArgb: c['color']! as int,
      );
      bump('categories');
    }
    for (final s in list('customSubcategories')) {
      var parent = s['parent']! as String;
      if (parent.startsWith('custom:')) {
        final id = customId[parent.substring(7)];
        if (id == null) continue;
        parent = 'custom:$id';
      }
      final id = await _d.categories.addSubcategory(
        parent: parent,
        name: s['name']! as String,
        icon: s['icon']! as String,
      );
      if (id != null) bump('categories');
    }

    // Rules before rows, so ingest applies them like the first time.
    final haveRules = {
      for (final r in await _d.categories.watchRules().first) r.merchantKey,
    };
    for (final r in list('rules')) {
      final key = r['key']! as String;
      if (haveRules.contains(key)) continue;
      final cat =
          enumFromDb(Category.values, r['category'] as String?, Category.other);
      final manual = r['manual'] == true;
      if (manual) {
        await _d.categories.saveManualRule(
          MerchantRule(
            merchantKey: key,
            category: cat,
            updatedAt: r['at']! as int,
            matchType: enumFromDb(
              RuleMatch.values,
              r['match'] as String?,
              RuleMatch.exact,
            ),
            subcategory: r['sub'] as String?,
            customCategoryId: customId[r['custom']],
            manual: true,
          ),
        );
      } else {
        await _d.categories.learn(key, cat, at: r['at']! as int);
      }
      bump('rules');
    }

    // Accounts: create the missing ones, fill blanks on existing ones.
    var known = {
      for (final a in await _allAccounts()) _acct(a.bankName, a.last4): a,
    };
    for (final a in list('accounts')) {
      final bank = a['bank']! as String;
      final last4 = a['last4']! as String;
      final key = _acct(bank, last4);
      final type = enumFromDbOrNull(AccountType.values, a['type'] as String?);
      final existing = known[key];
      if (existing == null) {
        final id = await _d.accounts.create(
          NewAccount(
            kind: enumFromDb(
              AccountKind.values,
              a['kind'] as String?,
              AccountKind.account,
            ),
            bankName: bank,
            last4: last4,
            accountType: type,
            cardNetwork: enumFromDbOrNull(
              CardNetwork.values,
              a['network'] as String?,
            ),
            usage: enumFromDb(
              AccountUsage.values,
              a['usage'] as String?,
              AccountUsage.personal,
            ),
          ),
        );
        if (id == null) continue;
        bump('accounts');
        if (a['nickname'] != null) {
          await _d.accounts.rename(id, a['nickname'] as String?);
        }
        if (a['manual'] != null) {
          await _d.accounts.setManualBalance(
            id,
            a['manual'] as int?,
            a['manualAt'] as int?,
          );
        }
        if (a['hidden'] == true) {
          await _d.accounts.setHidden(id, hidden: true);
        }
      } else {
        if (existing.nickname == null && a['nickname'] != null) {
          await _d.accounts.rename(existing.id, a['nickname'] as String?);
        }
        if (existing.accountType == null && type != null) {
          await _d.accounts.setType(existing.id, type);
        }
        if (existing.manualBalanceMinor == null && a['manual'] != null) {
          await _d.accounts.setManualBalance(
            existing.id,
            a['manual'] as int?,
            a['manualAt'] as int?,
          );
        }
      }
    }
    final book = await _d.loans.watch().first;
    final haveLoans = {
      for (final l in [...book.loans, ...book.merged])
        _acct(l.bankName, l.last4): l,
    };
    for (final l in list('loans')) {
      final draft = LoanDraft(
        bankName: l['bank']! as String,
        last4: l['last4'] as String?,
        principalMinor: l['principal']! as int,
        rateBps: l['rate']! as int,
        tenureMonths: l['tenure']! as int,
        startDay: l['startDay'] as int?,
        outstandingMinor: l['outstanding'] as int?,
      );
      final have = haveLoans[_acct(draft.bankName, draft.last4 ?? '')];
      if (have == null) {
        if (await _d.loans.create(draft) != null) bump('loans');
      } else if (have.principalMinor == null) {
        await _d.loans.update(have.id, draft);
        bump('loans');
      }
    }

    // Transactions through the single ledger write path, oldest first.
    final items = <IngestItem>[];
    final fixes = <String, Map<String, Object?>>{};
    for (final t in list('transactions')) {
      final sources = [
        for (final s in (t['sources'] as List?) ?? const <Object?>[])
          (s! as Map).cast<String, Object?>(),
      ];
      if (sources.isEmpty) {
        sources.add({
          'source': 'MANUAL',
          'id': 'backup:${t['hash']}',
          'sender': 'backup',
          'at': t['ts'],
        });
      }
      fixes[t['hash']! as String] = t;
      for (final s in sources) {
        final src =
            enumFromDb(Source.values, s['source'] as String?, Source.manual);
        final parsed = ParsedTransaction(
          amountMinor: t['amount']! as int,
          currency: t['currency']! as String,
          type: enumFromDb(
            TransactionType.values,
            t['type'] as String?,
            TransactionType.debit,
          ),
          bankName: t['bank']! as String,
          accountLast4: t['last4'] as String?,
          accountKind: enumFromDb(
            AccountKind.values,
            t['kind'] as String?,
            AccountKind.account,
          ),
          merchant: t['merchant'] as String?,
          upiId: t['upi'] as String?,
          referenceNumber: t['ref'] as String?,
          channel: enumFromDb(
            Channel.values,
            t['channel'] as String?,
            Channel.other,
          ),
          balanceMinor: t['balance'] as int?,
          availableLimitMinor: t['limit'] as int?,
          transactionTime: t['ts']! as int,
          hasExplicitTime: t['explicitTime'] == true,
          category: enumFromDb(
            Category.values,
            t['category'] as String?,
            Category.other,
          ),
          source: src,
          sender: (s['sender'] as String?) ?? 'backup',
          messageTimestamp: (s['at'] as int?) ?? (t['ts']! as int),
          confidence: (t['confidence'] as num?)?.toDouble() ?? 0.5,
          transactionHash: t['hash']! as String,
        );
        items.add(
          IngestItem(
            parsed: parsed,
            sourceMessageId: s['id']! as String,
            rawText: s['raw'] as String?,
            subject: s['subject'] as String?,
            note: t['note'] as String?,
          ),
        );
      }
    }
    final report = await _d.txs.ingestBatch(items);
    bump('transactions', report.inserted);

    // Per-row fields ingest cannot carry (category choices, sub-category).
    final byHash = {
      for (final t in await _allTx()) _hashOf(t.transactionHash): t,
    };
    for (final e in fixes.entries) {
      final row = byHash[e.key];
      if (row == null) continue;
      final t = e.value;
      final cat =
          enumFromDb(Category.values, t['category'] as String?, Category.other);
      final custom = customId[t['custom']];
      if (row.category != cat || row.customCategoryId != custom) {
        await _d.txs.setCategory([row.id], cat, customCategoryId: custom);
      }
      final sub = t['sub'] as String?;
      if (sub != null && row.subcategory != sub) {
        await _d.txs.setSubcategory(row.id, sub);
      }
    }

    // Accounts that now exist: map keys to ids for the sections below.
    known = {
      for (final a in await _allAccounts()) _acct(a.bankName, a.last4): a,
    };

    final haveRecurring = {
      for (final r in await _d.recurring.all())
        '${r.name}|${r.amountMinor}|${r.dayOfMonth}|${r.income}',
    };
    for (final r in list('recurring')) {
      final id = '${r['name']}|${r['amount']}|${r['day']}|${r['income']}';
      if (!haveRecurring.add(id)) continue;
      await _d.recurring.add(
        RecurringDraft(
          name: r['name']! as String,
          amountMinor: r['amount']! as int,
          income: r['income'] == true,
          frequency: enumFromDb(
            RecurringFrequency.values,
            r['freq'] as String?,
            RecurringFrequency.monthly,
          ),
          dayOfMonth: r['day']! as int,
          month: r['month'] as int?,
          category: enumFromDb(
            Category.values,
            r['category'] as String?,
            Category.other,
          ),
          accountId: known[r['account']]?.id,
        ),
      );
      bump('recurring items');
    }

    final haveBudgets = {for (final b in await _d.budgets.all()) b.category};
    for (final b in list('budgets')) {
      final cat =
          enumFromDb(Category.values, b['category'] as String?, Category.other);
      if (haveBudgets.contains(cat)) continue;
      await _d.budgets.save(cat, b['limit']! as int);
      bump('budgets');
    }

    // Holdings: grouped by source because `record` takes one source per call.
    final haveHoldings = {
      for (final h in await _d.holdings.list()) h.identifier,
    };
    final bySource = <HoldingSource, List<HoldingSnapshot>>{};
    for (final h in list('holdings')) {
      final id = h['identifier']! as String;
      if (haveHoldings.contains(id)) continue;
      final src = enumFromDb(
        HoldingSource.values,
        h['source'] as String?,
        HoldingSource.manual,
      );
      (bySource[src] ??= []).add(
        HoldingSnapshot(
          kind: enumFromDb(
            HoldingKind.values,
            h['kind'] as String?,
            HoldingKind.other,
          ),
          name: h['name']! as String,
          identifier: id,
          asOf: (h['asOf'] as int?) ?? 0,
          units: (h['units'] as num?)?.toDouble(),
          valueMinor: h['value'] as int?,
          investedMinor: h['invested'] as int?,
          platform: h['note'] as String?,
        ),
      );
    }
    for (final e in bySource.entries) {
      bump('holdings', await _d.holdings.record(e.value, e.key));
    }

    final haveCards = await _d.cards.watchOverrides().first;
    for (final o in list('cardOverrides')) {
      final key = o['cardKey']! as String;
      if (haveCards.containsKey(key)) continue;
      await _d.cards.saveOverride(
        CardOverride(
          cardKey: key,
          setAt: o['setAt']! as int,
          billedMinor: o['billed'] as int?,
          minDueMinor: o['minDue'] as int?,
          dueEpochDay: o['dueDay'] as int?,
          unbilledMinor: o['unbilled'] as int?,
          outstandingMinor: o['outstanding'] as int?,
        ),
      );
      bump('card entries');
    }
    for (final p in list('cardPaid')) {
      final id = known[p['account']]?.id;
      final day = p['day'] as int?;
      if (id == null || day == null) continue;
      await _d.cardPaid.markPaid(id, day);
    }

    final links = (doc['loanLinks'] as Map?)?.cast<String, Object?>() ?? {};
    List<Map<String, Object?>> sub(String k) => [
          for (final e in (links[k] as List?) ?? const <Object?>[])
            (e! as Map).cast<String, Object?>(),
        ];
    for (final l in sub('tx')) {
      final tx = byHash[l['hash']];
      final loan = known[l['loan']];
      if (tx != null && loan != null) {
        await _d.loanLinks.linkTx(tx.id, loan.id);
      }
    }
    for (final l in sub('payee')) {
      final loan = known[l['loan']];
      if (loan != null) {
        await _d.loanLinks.linkPayee(l['payee']! as String, loan.id);
      }
    }
    for (final p in (links['dismissed'] as List?) ?? const <Object?>[]) {
      await _d.loanLinks.dismissPayee(p! as String);
    }

    final haveFx = {
      for (final r in await _d.forex.rates()) '${r.currency}|${r.day}',
    };
    var fxAdded = 0;
    for (final r in list('forex')) {
      if (!haveFx.add('${r['currency']}|${r['day']}')) continue;
      await _d.forex.upsert(
        ForexRate(
          currency: r['currency']! as String,
          day: r['day']! as int,
          inrPerUnit: (r['rate']! as num).toDouble(),
        ),
      );
      fxAdded++;
    }
    if (fxAdded > 0) {
      bump('forex rates', fxAdded);
      await _d.forex.recompute();
    }

    // Settings: only whitelisted preferences, merged over the current ones.
    final stored = (doc['settings'] as Map?)?.cast<String, Object?>() ?? {};
    for (final k in backupSettings) {
      final v = stored[k.name];
      if (v == null || v.runtimeType != k.defaultValue.runtimeType) continue;
      await _writeAny(k, v);
    }
    return BackupCounts({
      'transactions': added['transactions'] ?? 0,
      'accounts': added['accounts'] ?? 0,
      'rules': added['rules'] ?? 0,
      'categories': added['categories'] ?? 0,
      'budgets': added['budgets'] ?? 0,
      'recurring items': added['recurring items'] ?? 0,
      'holdings': added['holdings'] ?? 0,
      'card entries': added['card entries'] ?? 0,
      'loans': added['loans'] ?? 0,
      'forex rates': added['forex rates'] ?? 0,
    });
  }

  Future<void> _writeAny(SettingKey<Object> k, Object v) async {
    if (v is bool) {
      await _d.settings.write(SettingKey<bool>(k.name, false), v);
    } else if (v is int) {
      await _d.settings.write(SettingKey<int>(k.name, 0), v);
    } else if (v is String) {
      await _d.settings.write(SettingKey<String>(k.name, ''), v);
    }
  }
}
