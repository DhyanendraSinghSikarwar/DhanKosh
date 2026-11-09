// Quick-add links pre-fill the Add form (FR-08-30).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/add_draft.dart';
import 'package:parser_core/parser_core.dart';

void main() {
  test('amount, merchant, category and direction are read', () {
    final d = addDraftFromLink({
      'amount': '1,250.50',
      'merchant': ' Chai Point ',
      'category': 'food',
      'type': 'in',
    })!;
    expect(d.amountMinor, 125050);
    expect(d.merchant, 'Chai Point');
    expect(d.category, Category.food);
    expect(d.type, TransactionType.credit);
  });

  test('bad or missing parameters are ignored', () {
    expect(addDraftFromLink({}), isNull);
    expect(addDraftFromLink({'amount': 'abc', 'category': 'zzz'}), isNull);
    expect(addDraftFromLink({'amount': '-5'}), isNull);
    final d = addDraftFromLink({'amount': '99', 'type': 'weird'})!;
    expect(d.amountMinor, 9900);
    expect(d.type, isNull);
  });
}
