// Cards screen and Home strip (FR-14-07, FR-14-09, FR-14-12, FR-14-13).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_flow_source_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_paid_store_impl.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_actions.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_service.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/presentation/cards_home_strip.dart';
import 'package:hisaab/features/credit_cards/presentation/credit_cards_screen.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

void main() {
  late TestEnv env;
  late CardDueRepositoryImpl dues;
  late int cardId;

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
    dues = CardDueRepositoryImpl(env.db);
    await dues.recordNotice(
      NewCardNotice(
        isPayment: false,
        source: CardDueSource.sms,
        receivedAt: now - 86400000,
        processedAt: now - 86400000,
        bankName: 'HDFC',
        last4: '5678',
        totalDueMinor: 1234500,
        minDueMinor: 62000,
        dueEpochDay: CardDay.ofMs(now) + 10,
        statementEpochDay: CardDay.ofMs(now) - 2,
      ),
    );
  });
  tearDown(() => env.close());

  Future<void> pump(WidgetTester t, Widget home) async {
    t.view.physicalSize = const Size(800, 2000);
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
  }

  testWidgets(
      'shows billed, min due, due label and Mark paid / Undo '
      '(FR-14-09, FR-14-13)', (t) async {
    await pump(t, const CreditCardsScreen());
    expect(
      find.descendant(
        of: find.byKey(Key('card_tile_$cardId')),
        matching: find.text('₹12,345.00'),
      ),
      findsOneWidget,
    );
    expect(find.text('₹620.00'), findsOneWidget);
    expect(find.text('Due in 10 days'), findsOneWidget);
    await t.tap(find.byKey(Key('card_mark_paid_$cardId')));
    await settle(t);
    expect(find.text('Marked paid'), findsOneWidget);
    expect(await env.count('transactions'), 0);
    await t.tap(find.byKey(Key('card_undo_$cardId')));
    await settle(t);
    expect(find.text('Due in 10 days'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets(
      'edit amounts overrides billed, Reset all clears it '
      '(FR-14-07)', (t) async {
    await pump(t, const CreditCardsScreen());
    await t.tap(find.byKey(Key('card_edit_$cardId')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    expect(find.text('Calculated ₹12,345.00'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('card_save'))).onPressed,
      isNull,
    );
    await t.enterText(find.byKey(const Key('card_field_billed')), '9000');
    await t.pump();
    await t.tap(find.byKey(const Key('card_save')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    expect(find.text('₹9,000.00'), findsOneWidget);
    expect(find.byKey(Key('card_edited_$cardId')), findsOneWidget);

    await t.tap(find.byKey(Key('card_edit_$cardId')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    await t.tap(find.byKey(const Key('card_reset_all')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    expect(
      find.descendant(
        of: find.byKey(Key('card_tile_$cardId')),
        matching: find.text('₹12,345.00'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(Key('card_edited_$cardId')), findsNothing);
    await teardownApp(t);
  });

  testWidgets('invalid amount disables Save (FR-14-07)', (t) async {
    await pump(t, const CreditCardsScreen());
    await t.tap(find.byKey(Key('card_edit_$cardId')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    await t.enterText(find.byKey(const Key('card_field_billed')), 'abc');
    await t.pump();
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('card_save'))).onPressed,
      isNull,
    );
    await teardownApp(t);
  });

  testWidgets('Home strip shows total owed and a row per card (FR-14-12)',
      (t) async {
    await pump(t, const Scaffold(body: CardsHomeStrip()));
    expect(find.byKey(const Key('home_cards_total')), findsOneWidget);
    expect(find.text('₹12,345.00'), findsOneWidget);
    expect(find.textContaining('••5678'), findsOneWidget);
    await teardownApp(t);
  });
}
