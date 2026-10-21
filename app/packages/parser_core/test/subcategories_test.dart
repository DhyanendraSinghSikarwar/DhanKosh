// Sub-category guess (FR-06-17, TC-06-26).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  test('the merchant picks the first matching sub-category', () {
    expect(Subcategories.guess(Category.food, 'Swiggy'), 'Food delivery');
    expect(Subcategories.guess(Category.transport, 'Uber'), 'Cabs & rides');
    expect(Subcategories.guess(Category.taxes, 'ITD TDS'), 'Income tax');
    expect(Subcategories.guess(Category.food, 'Starbucks'), 'Cafés & coffee');
    expect(
      Subcategories.guess(Category.bills, 'Jio recharge'),
      'Mobile recharge',
    );
  });

  test('the UPI id is searched together with the merchant', () {
    expect(
      Subcategories.guess(Category.food, null, 'zomato@icici'),
      'Food delivery',
    );
    expect(Subcategories.guess(Category.food, null), isNull);
    expect(Subcategories.guess(Category.food, 'Unknown Shop'), isNull);
  });

  test('a user choice beats the guess, and the fallbacks follow', () {
    expect(
      Subcategories.of(Category.food, 'Dining out', 'Swiggy', null),
      'Dining out',
    );
    expect(
      Subcategories.of(Category.food, null, 'Swiggy', null),
      'Food delivery',
    );
    // A category with one pattern-less sub-category uses it.
    expect(
      Subcategories.of(Category.cash, null, 'ATM', null),
      'ATM withdrawal',
    );
    // Categories with none show "Other".
    expect(
      Subcategories.of(Category.salary, null, 'Acme', null),
      Subcategories.other,
    );
    expect(
      Subcategories.of(Category.food, null, 'Unknown Shop', null),
      Subcategories.other,
    );
  });

  test('the catalogue has the 22 categories and 86 sub-categories', () {
    var subs = 0;
    var cats = 0;
    for (final c in Category.values) {
      final list = Subcategories.builtIn(c);
      if (list.isNotEmpty) cats++;
      subs += list.length;
    }
    expect(cats, 22);
    expect(subs, 86);
  });
}
