import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/categorization/domain/category_repository.dart';
import 'package:hisaab/features/categorization/domain/custom_category.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:parser_core/parser_core.dart';

/// A row for widget tests; amount in paise.
LedgerTx fakeTx(
  int id,
  int amountMinor,
  DateTime at, {
  String? merchant,
  TransactionType type = TransactionType.debit,
  Category category = Category.other,
  String? upiId,
  String? note,
  int? accountId,
  bool needsReview = false,
  String? reviewReason,
}) =>
    LedgerTx(
      id: id,
      amountMinor: amountMinor,
      currency: 'INR',
      type: type,
      bankName: 'HDFC',
      accountLast4: '1234',
      accountKind: AccountKind.account,
      accountId: accountId,
      merchant: merchant,
      upiId: upiId,
      channel: Channel.upi,
      timestamp: at.millisecondsSinceEpoch,
      hasExplicitTime: true,
      category: category,
      transactionHash: 'h$id',
      confidence: 1,
      needsReview: needsReview,
      reviewReason: reviewReason,
      note: note,
      createdAt: at.millisecondsSinceEpoch,
    );

/// In-memory ledger that filters like the real one (kind, period, query,
/// account, category) and records writes.
class FakeTxRepo implements TransactionRepository {
  FakeTxRepo(this.rows, {this.pairs = const []});

  List<LedgerTx> rows;
  List<ReviewPair> pairs;
  List<TxSourceRow> sources = [];
  final _changes = StreamController<void>.broadcast();

  final categorySets = <(List<int>, Category, int?)>[];
  final notes = <(int, String?)>[];
  final deleted = <int>[];
  final merged = <int>[];
  final kept = <int>[];
  final applied = <MerchantRule>[];
  final manual = <Map<String, Object?>>[];

  bool _matches(LedgerTx t, LedgerFilter f) {
    if (f.fromMs != null && t.timestamp < f.fromMs!) return false;
    if (f.toMs != null && t.timestamp >= f.toMs!) return false;
    if (f.accountId != null && t.accountId != f.accountId) return false;
    if (f.category != null && t.category != f.category) return false;
    final k = switch (f.kind) {
      TxKind.all => true,
      TxKind.income => t.type == TransactionType.credit,
      TxKind.spends => t.type == TransactionType.debit,
      TxKind.investments => t.type == TransactionType.investment,
      TxKind.transfers => t.type == TransactionType.transfer,
      TxKind.review => t.needsReview,
    };
    if (!k) return false;
    final q = f.query.toLowerCase();
    return q.isEmpty ||
        (t.merchant ?? '').toLowerCase().contains(q) ||
        (t.note ?? '').toLowerCase().contains(q) ||
        '${t.amountMinor ~/ 100}'.startsWith(q);
  }

  @override
  Stream<List<LedgerTx>> watch(LedgerFilter filter, {int? limit}) =>
      Stream.multi((c) {
        void emit() => c.add([
              for (final t in rows)
                if (_matches(t, filter)) t,
            ]);
        emit();
        final sub = _changes.stream.listen((_) => emit());
        c.onCancel = sub.cancel;
      });

  @override
  Stream<int> watchReviewCount() => Stream.value(pairs.length);

  @override
  Stream<List<ReviewPair>> watchReviewPairs() => Stream.multi((c) {
        c.add(pairs);
        final sub = _changes.stream.listen((_) => c.add(pairs));
        c.onCancel = sub.cancel;
      });

  @override
  Future<LedgerTx?> byId(int id) async {
    for (final t in rows) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<List<TxSourceRow>> sourcesOf(int id) async => sources;

  @override
  Future<void> setCategory(
    List<int> ids,
    Category category, {
    int? customCategoryId,
    String? subcategory,
  }) async {
    categorySets.add((ids, category, customCategoryId));
    rows = [
      for (final t in rows)
        if (ids.contains(t.id))
          fakeTx(
            t.id,
            t.amountMinor,
            DateTime.fromMillisecondsSinceEpoch(t.timestamp),
            merchant: t.merchant,
            type: t.type,
            category: category,
            upiId: t.upiId,
          )
        else
          t,
    ];
    _changes.add(null);
  }

  @override
  Future<void> setNote(int id, String? note) async => notes.add((id, note));

  @override
  Future<int> deleteTransactions(List<int> ids) async {
    deleted.addAll(ids);
    rows = [
      for (final t in rows)
        if (!ids.contains(t.id)) t,
    ];
    _changes.add(null);
    return ids.length;
  }

  @override
  Future<void> mergeFlagged(int id) async {
    merged.add(id);
    pairs = [
      for (final p in pairs)
        if (p.flagged.id != id) p,
    ];
    _changes.add(null);
  }

  @override
  Future<void> keepSeparate(int id) async {
    kept.add(id);
    pairs = [
      for (final p in pairs)
        if (p.flagged.id != id) p,
    ];
    _changes.add(null);
  }

  @override
  Future<int> applyRuleToPast(MerchantRule rule) async {
    applied.add(rule);
    return 3;
  }

  @override
  Future<int> countRuleMatches(MerchantRule rule) async => 3;

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
    manual.add({
      'amountMinor': amountMinor,
      'type': type,
      'merchant': merchant,
      'category': category,
      'accountId': accountId,
      'note': note,
    });
    return const IngestResult(IngestOutcome.inserted, transactionId: 99);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeAccountRepo implements AccountRepository {
  FakeAccountRepo([this.accounts = const []]);
  final List<Account> accounts;

  @override
  Stream<List<Account>> watchVisible() => Stream.value(accounts);

  @override
  Future<Account?> byId(int id) async {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeCategoryRepo implements CategoryRepository {
  final saved = <MerchantRule>[];
  final customs = <CustomCategory>[];

  @override
  Stream<List<CustomCategory>> watchCustomCategories() => Stream.value(customs);

  @override
  Future<void> saveManualRule(MerchantRule rule, {String? previousKey}) async =>
      saved.add(rule);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Pumps [home] (and extra [routes]) in a router with fakes and unmasked
/// amounts.
Future<void> pumpLedgerApp(
  WidgetTester tester, {
  required Widget home,
  required FakeTxRepo txs,
  FakeAccountRepo? accounts,
  FakeCategoryRepo? categories,
  List<GoRoute> routes = const [],
  bool dark = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      ...routes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(txs),
        accountRepositoryProvider
            .overrideWithValue(accounts ?? FakeAccountRepo()),
        categoryRepositoryProvider
            .overrideWithValue(categories ?? FakeCategoryRepo()),
        hideAmountsProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
      ),
    ),
  );
  await tester.pump();
}
