import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/test_env.dart';

MerchantRule rule(
  String key,
  Category c, {
  bool manual = false,
  RuleMatch m = RuleMatch.exact,
}) =>
    MerchantRule(
      merchantKey: key,
      category: c,
      updatedAt: 1,
      manual: manual,
      matchType: m,
    );

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  // FR-09-10
  test('rule precedence: manual exact, longest manual contains, learned', () {
    final set = RuleSet([
      rule('swiggy', Category.shopping),
      rule('swig', Category.gifts, manual: true, m: RuleMatch.contains),
      rule('swiggy ins', Category.fuel, manual: true, m: RuleMatch.contains),
      rule('uber', Category.travel, manual: true),
    ]);
    Category? of(String? m, {TransactionType t = TransactionType.debit}) =>
        set.ruleFor(merchant: m, upiId: null, type: t)?.category;
    expect(of('Uber'), Category.travel);
    expect(of('Swiggy Instamart'), Category.fuel);
    expect(of('swiggy'), Category.gifts); // manual contains beats learned
    expect(of('Zomato'), isNull);
    expect(of('Uber', t: TransactionType.transfer), isNull);
  });

  test('learn skips short keys and manual rules', () async {
    expect(await env.categories.learn('a', Category.food, at: 1), isFalse);
    await env.categories
        .saveManualRule(rule('x1', Category.gifts, manual: true));
    expect(await env.categories.learn('x1', Category.food, at: 1), isFalse);
    expect(await env.categories.learn('zomato', Category.food, at: 1), isTrue);
    expect(
      await env.categories.learn('zomato', Category.groceries, at: 2),
      isTrue,
    );
    final rules = await env.categories.watchRules().first;
    expect(rules.first.manual, isTrue);
    expect(rules.last.category, Category.groceries);
  });

  test('saveManualRule replaces the previous key', () async {
    await env.categories
        .saveManualRule(rule('old', Category.gifts, manual: true));
    await env.categories.saveManualRule(
      rule('new', Category.gifts, manual: true),
      previousKey: 'old',
    );
    expect(
        (await env.categories.watchRules().first).map((r) => r.merchantKey), [
      'new',
    ]);
  });

  // FR-09-13
  test('custom sub-categories are unique per parent', () async {
    final id = await env.categories.addCustomCategory(
      name: 'Pets',
      icon: 'pets',
      colorArgb: 1,
    );
    final p = 'custom:$id';
    expect(
      await env.categories.addSubcategory(parent: p, name: 'Food', icon: 'i'),
      isNotNull,
    );
    expect(
      await env.categories.addSubcategory(parent: p, name: 'Food', icon: 'i'),
      isNull,
    );
    expect(
      await env.categories
          .addSubcategory(parent: 'FOOD', name: 'Food', icon: 'i'),
      isNotNull,
    );
    expect((await env.categories.watchSubcategories(p).first).length, 1);
  });
}
