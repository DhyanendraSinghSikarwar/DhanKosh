import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/categorization/domain/category_repository.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/categorization/presentation/rules_screen.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

class _Rules implements CategoryRepository {
  _Rules(this.rules);
  List<MerchantRule> rules;
  final _c = StreamController<void>.broadcast();

  @override
  Stream<List<MerchantRule>> watchRules() => Stream.multi((s) {
        s.add(rules);
        final sub = _c.stream.listen((_) => s.add(rules));
        s.onCancel = sub.cancel;
      });

  @override
  Future<void> saveManualRule(MerchantRule rule, {String? previousKey}) async {
    rules = [
      for (final r in rules)
        if (r.merchantKey != (previousKey ?? rule.merchantKey)) r,
      rule,
    ];
    _c.add(null);
  }

  @override
  Future<void> deleteRule(String key) async {
    rules = [
      for (final r in rules)
        if (r.merchantKey != key) r,
    ];
    _c.add(null);
  }

  @override
  Future<bool> learn(String key, Category category, {required int at}) async {
    rules = [
      ...rules,
      MerchantRule(merchantKey: key, category: category, updatedAt: at),
    ];
    _c.add(null);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  Future<void> pump(WidgetTester t, _Rules cats, FakeTxRepo txs) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(cats),
          transactionRepositoryProvider.overrideWithValue(txs),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const RulesScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  // FR-09-08, FR-09-09, FR-09-12
  testWidgets('empty state, then add a rule with apply-to-past', (t) async {
    final cats = _Rules([]);
    final txs = FakeTxRepo([]);
    await pump(t, cats, txs);
    expect(find.byKey(const Key('rules_empty')), findsOneWidget);
    await t.tap(find.byKey(const Key('rule_add')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('rule_key')), 'Zomato');
    await t.pumpAndSettle();
    expect(find.text('Would change 3 past transactions'), findsOneWidget);
    await t.tap(find.byKey(const Key('rule_apply')));
    await t.tap(find.byKey(const Key('rule_save')));
    await t.pumpAndSettle();
    expect(find.text('Your rules · 1'), findsOneWidget);
    expect(find.byKey(const Key('rule_zomato')), findsOneWidget);
    expect(txs.applied.single.merchantKey, 'zomato');
  });

  // FR-09-12
  testWidgets('learned apart; remove shows Undo and restores', (t) async {
    final cats = _Rules([
      const MerchantRule(
        merchantKey: 'uber',
        category: Category.transport,
        updatedAt: 1,
        manual: true,
      ),
      const MerchantRule(
        merchantKey: 'swiggy',
        category: Category.food,
        updatedAt: 2,
      ),
    ]);
    await pump(t, cats, FakeTxRepo([]));
    expect(find.text('Your rules · 1'), findsOneWidget);
    expect(find.text('Learned · 1'), findsOneWidget);
    await t.tap(find.byKey(const Key('rule_remove_uber')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rule_uber')), findsNothing);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rule_uber')), findsOneWidget);
  });
}
