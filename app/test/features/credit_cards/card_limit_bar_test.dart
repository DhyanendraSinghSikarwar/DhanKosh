// The Home card bar and which accounts count as credit cards (FR-14-29,
// FR-14-30).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_service.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/domain/card_view.dart';
import 'package:hisaab/features/credit_cards/presentation/card_limit_bar.dart';
import 'package:parser_core/parser_core.dart';

CardView _view({
  required int limit,
  required int billed,
  required int unbilled,
  int? available,
}) =>
    CardView(
      card: CardLimit(
        id: 1,
        name: 'SBI Card',
        bankName: 'SBI',
        last4: '1234',
        position: CardPosition(
          limitMinor: limit,
          billedMinor: billed,
          unbilledMinor: unbilled,
        ),
        paid: false,
        availableMinor: available,
      ),
      usage: AccountUsage.personal,
    );

Account _acct({AccountType? type, int? limit, AccountKind? kind}) => Account(
      id: 1,
      bankName: 'SBI',
      last4: '1234',
      kind: kind ?? AccountKind.card,
      createdAt: 0,
      accountType: type,
      availableLimitMinor: limit,
    );

void main() {
  test('the three parts add up to the limit', () {
    final b = _view(
      limit: 10000000,
      billed: 2000000,
      unbilled: 1000000,
      available: 7000000,
    ).limitBar!;
    expect((b.billed, b.unbilled, b.left), (2000000, 1000000, 7000000));
  });

  test('used but not billed counts as unbilled; billed is capped by used', () {
    final b = _view(
      limit: 100000,
      billed: 90000,
      unbilled: 0,
      available: 80000,
    ).limitBar!;
    expect(b.billed, 20000);
    expect(b.unbilled, 0);
    expect(b.left, 80000);
    expect(_view(limit: 0, billed: 0, unbilled: 0).limitBar, isNull);
  });

  testWidgets('the bar draws a segment per part with its amounts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardLimitBar(
            view: _view(
              limit: 10000000,
              billed: 2000000,
              unbilled: 1000000,
              available: 7000000,
            ),
            masked: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('home_card_bar_1')), findsOneWidget);
    expect(find.textContaining('Left'), findsOneWidget);
    expect(find.textContaining('Unbilled'), findsOneWidget);
    expect(find.textContaining('Billed'), findsWidgets);
  });

  test('a card with no stated limit still counts as a credit card', () {
    expect(isCreditCardAccount(_acct()), isTrue);
    expect(isCreditCardAccount(_acct(type: AccountType.creditCard)), isTrue);
    expect(isCreditCardAccount(_acct(type: AccountType.debitCard)), isFalse);
    expect(isCreditCardAccount(_acct(type: AccountType.prepaidCard)), isFalse);
    expect(isCreditCardAccount(_acct(kind: AccountKind.account)), isFalse);
  });
}
