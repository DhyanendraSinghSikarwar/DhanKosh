// Card page, Home cards card and Book filter (FR-14-24..28, FR-17-44).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_flow_source_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_paid_store_impl.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_actions.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_service.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/domain/card_view.dart';
import 'package:hisaab/features/credit_cards/presentation/card_detail_screen.dart';
import 'package:hisaab/features/credit_cards/presentation/cards_home_strip.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

void main() {
  late TestEnv env;
  late CardDueRepositoryImpl dues;
  late int cardId;
  late int bizId;

  setUp(() async {
    env = TestEnv();
    final now = DateTime.now().millisecondsSinceEpoch;
    cardId = (await env.accounts.create(
      const NewAccount(
        kind: AccountKind.card,
        bankName: 'HDFC Bank',
        last4: '5678',
        accountType: AccountType.creditCard,
      ),
    ))!;
    bizId = (await env.accounts.create(
      const NewAccount(
        kind: AccountKind.card,
        bankName: 'Axis Bank',
        last4: '9012',
        accountType: AccountType.creditCard,
        usage: AccountUsage.business,
      ),
    ))!;
    dues = CardDueRepositoryImpl(env.db);
    for (final (bank, last4, total) in [
      ('HDFC', '5678', 1234500),
      ('Axis', '9012', 400000),
    ]) {
      await dues.recordNotice(
        NewCardNotice(
          isPayment: false,
          source: CardDueSource.sms,
          receivedAt: now - 86400000,
          processedAt: now - 86400000,
          bankName: bank,
          last4: last4,
          totalDueMinor: total,
          minDueMinor: 62000,
          dueEpochDay: CardDay.ofMs(now) + 10,
          statementEpochDay: CardDay.ofMs(now) - 2,
        ),
      );
    }
  });
  tearDown(() => env.close());

  Future<ProviderContainer> pump(WidgetTester t, Widget home) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final paid = CardPaidStoreImpl(env.settings);
    final service = CardDueService(
      accounts: env.accounts,
      dues: dues,
      statements: StatementRepositoryImpl(env.db),
      flow: CardFlowSourceImpl(env.txs),
      paid: paid,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          hideAmountsProvider.overrideWith((_) => Stream.value(false)),
          cardDueServiceProvider.overrideWithValue(service),
          cardDueActionsProvider
              .overrideWithValue(CardDueActions(dues: dues, paid: paid)),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(t);
    return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  }

  // FR-14-24
  testWidgets('card page shows the figures and the statement note', (t) async {
    await pump(t, CardDetailScreen(cardId: cardId));
    expect(
      t.widget<Text>(find.byKey(const Key('card_detail_balance'))).data,
      '₹12,345',
    );
    expect(
      t.widget<Text>(find.byKey(const Key('card_ov_min'))).data,
      '₹620',
    );
    expect(
      t.widget<Text>(find.byKey(const Key('card_detail_note'))).data,
      startsWith('Filled from statement dated'),
    );
    expect(find.text('Upcoming payments'), findsOneWidget);
    expect(find.text('Statement history'), findsOneWidget);
    expect(find.byKey(const Key('card_detail_edited')), findsNothing);
    await teardownApp(t);
  });

  // FR-14-26, FR-14-27
  testWidgets('Edit overrides balance and limit; edited tag; Cancel keeps',
      (t) async {
    await pump(t, CardDetailScreen(cardId: cardId));
    await t.tap(find.byKey(const Key('card_detail_edit')));
    await t.pump();
    await t.enterText(find.byKey(const Key('card_edit_stmt')), '20000');
    await t.enterText(find.byKey(const Key('card_edit_limit')), '100000');
    // Cancel leaves everything as it was.
    await t.tap(find.byKey(const Key('card_edit_cancel')));
    await t.pump();
    expect(find.byKey(const Key('card_detail_edited')), findsNothing);
    expect(
      t.widget<Text>(find.byKey(const Key('card_detail_balance'))).data,
      '₹12,345',
    );

    await t.tap(find.byKey(const Key('card_detail_edit')));
    await t.pump();
    await t.enterText(find.byKey(const Key('card_edit_stmt')), '20000');
    await t.enterText(find.byKey(const Key('card_edit_limit')), '100000');
    await t.tap(find.byKey(const Key('card_edit_save')));
    await settle(t);
    await settle(t);
    expect(find.byKey(const Key('card_detail_edited')), findsOneWidget);
    expect(
      t.widget<Text>(find.byKey(const Key('card_detail_balance'))).data,
      '₹20,000',
    );
    expect(
      t.widget<Text>(find.byKey(const Key('card_ov_limit'))).data,
      '₹1,00,000',
    );
    final stored = await t.runAsync(
      () => env.settings.read(cardLimitOverridesKey),
    );
    expect(stored, 'hdfc bank:5678=10000000');
    await teardownApp(t);
  });

  // FR-14-25
  testWidgets('Home cards card follows the Book', (t) async {
    final c = await pump(t, const Scaffold(body: CardsHomeStrip()));
    expect(find.byKey(Key('home_card_$cardId')), findsOneWidget);
    expect(find.byKey(Key('home_card_$bizId')), findsOneWidget);
    c.read(bookProvider.notifier).set(Book.business);
    await t.pump();
    expect(find.byKey(Key('home_card_$cardId')), findsNothing);
    expect(find.byKey(Key('home_card_$bizId')), findsOneWidget);
    c.read(bookProvider.notifier).set(Book.personal);
    await t.pump();
    expect(find.byKey(Key('home_card_$cardId')), findsOneWidget);
    expect(find.byKey(Key('home_card_$bizId')), findsNothing);
    expect(
      t
          .widget<Text>(find.byKey(const Key('home_cards_total')))
          .textSpan!
          .toPlainText(),
      'Total due ₹12,345',
    );
    await teardownApp(t);
  });
}
