import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/activity_log/data/activity_log_repository_impl.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/activity_log/presentation/activity_log_screen.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_net_worth_card.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

List<RouteBase> _routes(List<String> visited, {bool nw = false}) => [
      GoRoute(
        path: '/',
        builder: (_, __) => nw
            ? Consumer(
                builder: (_, ref, __) => Scaffold(
                  body: HomeNetWorthCard(
                    masked: ref.watch(hideAmountsProvider).value ?? true,
                  ),
                ),
              )
            : const DashboardHomeScreen(),
      ),
      GoRoute(path: '/activity', builder: (_, __) => const ActivityLogScreen()),
      for (final p in [
        '/accounts',
        '/analysis',
        '/more',
        '/portfolio',
        '/review',
        '/statements',
        '/transaction/:id',
      ])
        GoRoute(
          path: p,
          builder: (_, s) {
            visited.add(s.uri.path);
            return Scaffold(body: Text('page ${s.uri.path}'));
          },
        ),
    ];

final Finder _value = find.descendant(
  of: find.byKey(const Key('home_networth_value')),
  matching: find.byType(Text),
);

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  int now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> seed(WidgetTester t, {bool hide = false}) =>
      t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, hide);
        await env.settings.write(SettingKeys.smsPromptDismissed, true);
        await env.accounts.create(
          const NewAccount(
            kind: AccountKind.account,
            bankName: 'HDFC Bank',
            last4: '1234',
            balanceMinor: 5000000,
          ),
        );
        await env.ingest(
          parsed(amountMinor: 245050, time: now() - 1000, ref: 'AAA111111'),
        );
      });

  // FR-17-26, FR-17-36: the card stays available but is not on Home.
  testWidgets('net worth card shows value, opens Portfolio', (t) async {
    await seed(t);
    final visited = <String>[];
    await pumpApp(t, env, _routes(visited, nw: true));
    final v = t.widget<Text>(_value);
    expect(v.data, startsWith('₹'));
    expect(v.data, isNot(contains('•')));
    await t.tap(find.byKey(const Key('home_networth')));
    await settle(t);
    expect(visited, ['/portfolio']);
    await teardownApp(t);
  });

  // FR-17-26, FR-17-19
  testWidgets('net worth masked with hide-amounts', (t) async {
    await seed(t, hide: true);
    await pumpApp(t, env, _routes([], nw: true));
    expect(
      t.widget<Text>(_value).data,
      '₹••••',
    );
    await teardownApp(t);
  });

  // FR-17-36
  testWidgets('Home no longer shows the net worth card', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes([]));
    expect(find.byKey(const Key('home_networth')), findsNothing);
    await teardownApp(t);
  });

  // FR-17-27
  testWidgets('privacy badge and spent opens Analysis', (t) async {
    await seed(t);
    final visited = <String>[];
    await pumpApp(t, env, _routes(visited));
    expect(find.text('Data stays on this phone'), findsOneWidget);
    await t.tap(find.byKey(const Key('home_spent_tap')));
    await settle(t);
    expect(visited, ['/analysis']);
    await teardownApp(t);
  });

  // FR-17-25: hidden when empty, locked statement row opens Statements
  testWidgets('needs attention hidden, then shows locked statement', (t) async {
    await seed(t);
    final visited = <String>[];
    await pumpApp(t, env, _routes(visited));
    expect(find.byKey(const Key('home_attention')), findsNothing);
    await t.runAsync(
      () => StatementRepositoryImpl(env.db).insert(
        NewStatement(
          key: 'file:abc',
          source: StatementSource.file,
          sender: 'bank',
          fileName: 's.pdf',
          receivedAt: now(),
          processedAt: now(),
          status: StatementStatus.locked,
        ),
      ),
    );
    await settle(t);
    expect(find.byKey(const Key('home_attention')), findsOneWidget);
    expect(find.text('1 statement needs attention'), findsOneWidget);
    await t.tap(find.byKey(const Key('attn_statement')));
    await settle(t);
    expect(visited, ['/statements']);
    await teardownApp(t);
  });

  // FR-22-16: unread badge on the bell, cleared by opening the Inbox
  testWidgets('bell badge counts unread, opening marks seen', (t) async {
    await seed(t);
    final log = ActivityLogRepositoryImpl(env.db);
    await t.runAsync(() async {
      await log.record(
        ActivityEntry(
          at: DateTime.now(),
          source: ActivitySource.smsScan,
          read: 3,
          relevant: 3,
          added: 1,
        ),
      );
      await log.record(
        ActivityEntry(
          at: DateTime.now(),
          source: ActivitySource.problems,
          read: 2,
          note: 'AX-HDFCBK',
        ),
      );
    });
    await pumpApp(t, env, _routes([]));
    Badge badge() => t.widget<Badge>(find.byKey(const Key('home_bell_badge')));
    expect(badge().isLabelVisible, isTrue);
    expect((badge().label! as Text).data, '2');
    await t.tap(find.byKey(const Key('home_bell')));
    await settle(t);
    expect(find.text('Inbox'), findsOneWidget);
    final seen =
        await t.runAsync(() => env.settings.read(SettingKeys.activityLastSeen));
    expect(seen, greaterThan(0));
    // Group chip filters to problems only; its row shows an unread dot.
    await t.tap(find.byKey(const Key('group-problems')));
    await settle(t);
    await t.scrollUntilVisible(
      find.text('2 unreadable from AX-HDFCBK'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ActivityLogScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('inbox-unread-dot')), findsOneWidget);
    expect(find.textContaining('3 SMS'), findsNothing);
    await teardownApp(t);
  });

  // FR-17-28: one action per empty state
  testWidgets('empty home offers import statement', (t) async {
    final visited = <String>[];
    await pumpApp(t, env, _routes(visited));
    expect(find.byKey(const Key('home_scan_sms')), findsOneWidget);
    await t.tap(find.text('Import your first statement'));
    await settle(t);
    expect(visited, ['/statements']);
    await teardownApp(t);
  });
}
