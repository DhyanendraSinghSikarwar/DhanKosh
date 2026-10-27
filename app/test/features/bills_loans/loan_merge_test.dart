// Loan duplicates, merge, unmerge (FR-15-12) and EMI bars (B13).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/sip_providers.dart';
import 'package:hisaab/features/loans/data/loan_account_repository_impl.dart';
import 'package:hisaab/features/loans/data/loan_link_repository_impl.dart';
import 'package:hisaab/features/loans/domain/amortization.dart';
import 'package:hisaab/features/loans/domain/loan_account_repository.dart';
import 'package:hisaab/features/loans/presentation/loan_emi_chart.dart';
import 'package:hisaab/features/loans/presentation/loan_link_prompt_screen.dart';
import 'package:hisaab/features/loans/presentation/loans_screen.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/sip_repository_impl.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  testWidgets('FR-15-12 duplicates: merge then unmerge', (t) async {
    final loans = LoanAccountRepositoryImpl(env.db);
    await loans.create(
      const LoanDraft(
        bankName: 'Test Lender',
        last4: '1111',
        principalMinor: 50000000,
        rateBps: 1000,
        tenureMonths: 60,
      ),
    );
    await loans.create(
      const LoanDraft(
        bankName: 'Test Lender',
        last4: '2222',
        principalMinor: 0,
        rateBps: 0,
        tenureMonths: 0,
      ),
    );
    // One lender message arrived without digits.
    await env.db
        .customStatement("UPDATE accounts SET last4 = '' WHERE last4 = '2222'");
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          recurringRepositoryProvider
              .overrideWithValue(RecurringRepositoryImpl(env.db)),
          sipRepositoryProvider.overrideWithValue(SipRepositoryImpl(env.db)),
          holdingRepositoryProvider
              .overrideWithValue(HoldingRepositoryImpl(env.db)),
          loanLinkRepositoryProvider
              .overrideWithValue(LoanLinkRepositoryImpl(env.db)),
          loanAccountRepositoryProvider.overrideWithValue(loans),
          hideAmountsProvider.overrideWith((_) => Stream.value(false)),
        ],
        child: const MaterialApp(home: LoansScreen()),
      ),
    );
    await settle(t);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Possible duplicates'), findsOneWidget);
    await t.tap(find.textContaining('Merge').first);
    await settle(t);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Possible duplicates'), findsNothing);
    final book = await t.runAsync(() => loans.watch().first);
    expect(book!.merged, hasLength(1));
    await teardownApp(t);
  });

  testWidgets('FR-15-09 prompt links the payment to the chosen loan',
      (t) async {
    final loans = LoanAccountRepositoryImpl(env.db);
    final id = await loans.create(
      const LoanDraft(
        bankName: 'Test Lender',
        last4: '3333',
        principalMinor: 10000000,
        rateBps: 1000,
        tenureMonths: 24,
      ),
    );
    final links = LoanLinkRepositoryImpl(env.db);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          recurringRepositoryProvider
              .overrideWithValue(RecurringRepositoryImpl(env.db)),
          sipRepositoryProvider.overrideWithValue(SipRepositoryImpl(env.db)),
          holdingRepositoryProvider
              .overrideWithValue(HoldingRepositoryImpl(env.db)),
          loanLinkRepositoryProvider.overrideWithValue(links),
          loanAccountRepositoryProvider.overrideWithValue(loans),
          hideAmountsProvider.overrideWith((_) => Stream.value(false)),
        ],
        child: const MaterialApp(home: LoanLinkPromptScreen(txId: 42)),
      ),
    );
    await settle(t);
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(Key('prompt-loan-$id')));
    await settle(t);
    expect((await links.read()).tx[42], id);
    await teardownApp(t);
  });

  test('B13 bars sum principal and interest, yearly when long', () {
    final short = [
      for (var i = 1; i <= 6; i++)
        Instalment(
          number: i,
          emiMinor: 100,
          principalMinor: 80,
          interestMinor: 20,
          due: null,
          balanceAfterMinor: 0,
        ),
    ];
    expect(LoanEmiChart.bars(short), hasLength(6));
    final long = [
      for (var i = 1; i <= 36; i++)
        Instalment(
          number: i,
          emiMinor: 100,
          principalMinor: 80,
          interestMinor: 20,
          due: null,
          balanceAfterMinor: 0,
        ),
    ];
    final bars = LoanEmiChart.bars(long);
    expect(bars, hasLength(3));
    expect(bars.first.principal, 960);
    expect(bars.first.interest, 240);
  });
}
