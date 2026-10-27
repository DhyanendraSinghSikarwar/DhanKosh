import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/category_detail_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/categorization/domain/category_detail.dart';
import 'package:hisaab/features/categorization/domain/category_repository.dart';
import 'package:hisaab/features/categorization/presentation/category_detail_screen.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/ui_harness.dart';

class _Repo implements CategoryRepository {
  final added = <String>[];

  @override
  Future<int?> addSubcategory({
    required String parent,
    required String name,
    required String icon,
  }) async {
    added.add('$parent/$name');
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

LedgerTx _tx(int id, DateTime day, int rupees, {String? sub, String? m}) =>
    LedgerTx(
      id: id,
      amountMinor: rupees * 100,
      currency: 'INR',
      type: TransactionType.debit,
      bankName: 'Test Bank',
      accountKind: AccountKind.card,
      channel: Channel.card,
      timestamp: epochMsOf(day, hour: 12),
      hasExplicitTime: true,
      category: Category.food,
      transactionHash: 'h$id',
      confidence: 1,
      needsReview: false,
      createdAt: 0,
      subcategory: sub,
      merchant: m,
    );

void main() {
  testWidgets(
      'category detail shows card spend, budget and adds sub (FR-09-14)',
      (t) async {
    final repo = _Repo();
    final months = [
      for (var i = 11; i >= 0; i--) addMonths(DateTime.utc(2026, 10), -i),
    ];
    final d = CategoryDetail.build(
      id: 'food',
      category: Category.food,
      customCategoryId: null,
      all: [
        _tx(1, DateTime.utc(2026, 10, 3), 1200, sub: 'Cafe', m: 'Cafe One'),
        _tx(2, DateTime.utc(2026, 9, 3), 800),
      ],
      months: months,
      budgetLimitMinor: 200000,
    );
    t.view
      ..physicalSize = const Size(420, 1000)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          hideAmountsProvider.overrideWith((ref) => Stream.value(false)),
          categoryRepositoryProvider.overrideWithValue(repo),
          categoryDetailProvider('food').overrideWith((ref) => Stream.value(d)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CategoryDetailScreen(id: 'food'),
        ),
      ),
    );
    await settle(t);
    expect(find.byKey(const Key('category-total')), findsOneWidget);
    expect(find.text('₹1,200'), findsWidgets);
    expect(find.byKey(const Key('category-budget')), findsOneWidget);
    expect(find.byKey(const Key('category-donut')), findsOneWidget);
    expect(find.byKey(const Key('category-trend')), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const Key('category-add-sub')));
    await settle(t);
    await t.enterText(find.byKey(const Key('subcategory-name')), 'Snacks');
    await t.tap(find.byKey(const Key('subcategory-save')));
    await settle(t);
    expect(repo.added, ['FOOD/Snacks']);
    await t.scrollUntilVisible(
      find.byKey(const Key('category-tx-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('category-tx-1')), findsOneWidget);
    expect(categoryParentKey('emiLoan'), 'EMI_LOAN');
    await teardownApp(t);
  });
}
