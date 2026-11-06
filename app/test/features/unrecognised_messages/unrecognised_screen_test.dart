// F-38 screens: the queue, Add from a message, Learned senders
// (FR-38-04, FR-38-07..09, FR-38-11). Every message is synthetic.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/unrecognised_providers.dart';
import 'package:hisaab/features/transactions_ledger/domain/add_draft.dart';
import 'package:hisaab/features/transactions_ledger/presentation/add_transaction_screen.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/add_from_unrecognised.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/learned_senders_screen.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/unrecognised_screen.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

import '../../support/fake_ledger.dart' show FakeAccountRepo;
import '../../support/fake_unrecognised.dart';
import '../../support/test_env.dart';

const _debit =
    'Rs.1,250.00 debited from A/c XX4821 on 05-11-26 to ZOMATO. Avl bal Rs.9,400.50';

void main() {
  late TestEnv env;
  late FakeUnrecognisedRepo repo;

  setUp(() {
    env = TestEnv();
    repo = FakeUnrecognisedRepo();
  });
  tearDown(() => env.close());

  Future<void> pump(
    WidgetTester t, {
    Widget home = const UnrecognisedScreen(),
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(900, 2200);
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(
          path: '/transactions/add',
          builder: (_, state) =>
              AddTransactionScreen(draft: state.extra as AddDraft?),
        ),
        GoRoute(
          path: '/review/unrecognised/senders',
          builder: (_, __) => const LearnedSendersScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          unrecognisedRepositoryProvider.overrideWithValue(repo),
          addFromUnrecognisedProvider.overrideWithValue(
            AddFromUnrecognised(queue: repo, ledger: env.txs),
          ),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          accountRepositoryProvider.overrideWithValue(FakeAccountRepo()),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          hideAmountsProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await t.pump();
  }

  Future<int> queue(WidgetTester t) async => (await t.runAsync(
        () => repo.offer(
          const NewUnrecognised(
            source: UnrecognisedSource.sms,
            sender: 'VM-NEWBNK-S',
            sourceMessageId: 'sms:1',
            body: _debit,
            receivedAt: 1790310600000,
          ),
        ),
      ))!;

  testWidgets('empty queue says everything is recognised', (t) async {
    await pump(t);
    expect(find.byKey(const Key('unrecognised_empty')), findsOneWidget);
  });

  testWidgets('a queued message shows what it looks like (FR-38-04)',
      (t) async {
    final id = await queue(t);
    await pump(t);
    expect(find.text('VM-NEWBNK-S'), findsOneWidget);
    final line = t.widget<Text>(find.byKey(Key('looks_like_$id'))).data!;
    expect(line, contains('1,250'));
    expect(line, contains('debit'));
    expect(line, contains('••4821'));
  });

  testWidgets('Dismiss hides the message and Undo brings it back', (t) async {
    final id = await queue(t);
    await pump(t);
    await t.runAsync(() async {
      await t.tap(find.byKey(Key('dismiss_$id')));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('unrecognised_empty')), findsOneWidget);
    // Let the snack bar finish sliding in before tapping its action.
    await t.pump(const Duration(milliseconds: 500));
    await t.runAsync(() async {
      await t.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await t.pump();
    await t.pump();
    expect(find.byKey(Key('unrecognised_$id')), findsOneWidget);
  });

  testWidgets('Add opens the form pre-filled; Save books it once (FR-38-11)',
      (t) async {
    final id = await queue(t);
    await pump(t);
    await t.runAsync(() async {
      await t.tap(find.byKey(Key('add_$id')));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await t.pumpAndSettle();
    expect(find.byKey(const Key('add_source_text')), findsOneWidget);
    expect(
      t.widget<TextField>(find.byKey(const Key('add_amount'))).controller!.text,
      '1250',
    );
    expect(
      t.widget<TextField>(find.byKey(const Key('add_payee'))).controller!.text,
      isNotEmpty,
    );
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('add_save')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
    expect(await t.runAsync(() => env.count('transactions')), 1);
    final m = await t.runAsync(() => repo.byId(id));
    expect(m!.status, UnrecognisedStatus.added);
    expect(m.transactionId, isNotNull);
    // The sender is now learned.
    expect(await t.runAsync(() => repo.pref(m.senderKey)), isNotNull);
  });

  testWidgets('Learned senders lists a sender and Forget removes it',
      (t) async {
    await t
        .runAsync(() => repo.learn('NEWBNK', bankName: 'ABC', last4: '4821'));
    await pump(t, home: const LearnedSendersScreen());
    expect(find.text('NEWBNK'), findsOneWidget);
    expect(find.textContaining('ABC ••4821'), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('forget_NEWBNK')));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('senders_empty')), findsOneWidget);
  });
}
