// Cards screen extras: cycle spend, statement history, late flag
// (FR-14-18..22). Fictional data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/data/card_bill_debit_source_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_flow_source_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_paid_store_impl.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_actions.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_service.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
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
  final now = DateTime.now().millisecondsSinceEpoch;
  final today = CardDay.ofMs(now);

  setUp(() async {
    env = TestEnv();
    cardId = (await env.accounts.create(
      const NewAccount(
        kind: AccountKind.card,
        bankName: 'HDFC Bank',
        last4: '5678',
        accountType: AccountType.creditCard,
      ),
    ))!;
    dues = CardDueRepositoryImpl(env.db);
    // Statement 25 days ago, due 6 days ago, nothing paid.
    await dues.recordNotice(
      NewCardNotice(
        isPayment: false,
        source: CardDueSource.sms,
        receivedAt: now - 25 * 86400000,
        processedAt: now - 25 * 86400000,
        bankName: 'HDFC',
        last4: '5678',
        totalDueMinor: 1234500,
        minDueMinor: 62000,
        dueEpochDay: today - 6,
        statementEpochDay: today - 25,
      ),
    );
  });
  tearDown(() => env.close());

  Future<void> pump(WidgetTester t) async {
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
      debits: CardBillDebitSourceImpl(env.txs),
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
        child: const MaterialApp(home: CreditCardsScreen()),
      ),
    );
    await settle(t);
    await settle(t);
  }

  testWidgets('overdue unpaid statement shows a late risk flag (FR-14-22)',
      (t) async {
    await pump(t);
    expect(find.byKey(Key('card_insights_$cardId')), findsOneWidget);
    expect(find.byKey(Key('card_late_$cardId')), findsOneWidget);
    expect(find.text('Late risk'), findsOneWidget);
    expect(find.byKey(Key('card_stmt_${cardId}_0')), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('Mark paid clears the flag and shows Paid (FR-14-20)', (t) async {
    await t.runAsync(
      () => CardPaidStoreImpl(env.settings).markPaid(cardId, today - 6),
    );
    await pump(t);
    expect(find.byKey(Key('card_late_$cardId')), findsNothing);
    expect(find.text('Paid'), findsOneWidget);
    await teardownApp(t);
  });
}
