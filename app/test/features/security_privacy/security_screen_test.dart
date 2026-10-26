import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/profile/domain/bank_identity.dart';
import 'package:hisaab/features/profile/domain/bank_identity_repository.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/domain/security_settings.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/features/security_privacy/presentation/security_privacy_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/statement_import/domain/saved_password.dart';
import 'package:hisaab/features/transactions_ledger/data/data_reset_repository_impl.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class _Lock implements AppLockService {
  @override
  Future<AuthAvailability> availability() async => AuthAvailability.available;
  @override
  Future<bool> authenticate() async => true;
}

class _Passwords implements SavedPasswordRepository {
  final items = [const SavedPassword(label: 'a', secret: 's')];
  @override
  Future<List<SavedPassword>> list() async => [...items];
  @override
  Future<void> add(SavedPassword p) async => items.add(p);
  @override
  Future<void> remove(String label) async =>
      items.removeWhere((e) => e.label == label);
}

class _Ids implements BankIdentityRepository {
  final removed = <int>[];
  @override
  Future<BankIdentity?> read(int id) async => null;
  @override
  Future<List<BankIdentity>> readAll() async =>
      [const BankIdentity(accountId: 7, customerId: 'x')];
  @override
  Future<void> save(BankIdentity i) async {}
  @override
  Future<void> remove(int id) async => removed.add(id);
}

class _Creds implements EmailCredentialStore {
  bool wiped = false;
  @override
  Future<String?> read() async => 'pw';
  @override
  Future<void> write(String p) async {}
  @override
  Future<void> wipe() async => wiped = true;
}

void main() {
  late TestEnv env;
  late _Passwords pw;
  late _Ids ids;
  late _Creds creds;
  late String route;

  setUp(() {
    env = TestEnv();
    pw = _Passwords();
    ids = _Ids();
    creds = _Creds();
    route = '';
  });
  tearDown(() => env.close());

  Future<ProviderContainer> pump(WidgetTester t, {bool lock = true}) async {
    await t.runAsync(() => env.settings.write(SettingKeys.appLock, lock));
    final c = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(env.settings),
        appLockServiceProvider.overrideWithValue(_Lock()),
        dataResetRepositoryProvider
            .overrideWithValue(DataResetRepositoryImpl(env.db)),
        savedPasswordRepositoryProvider.overrideWithValue(pw),
        bankIdentityRepositoryProvider.overrideWithValue(ids),
        emailCredentialStoreProvider.overrideWithValue(creds),
      ],
    );
    addTearDown(c.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SecurityPrivacyScreen(),
        ),
        GoRoute(
          path: '/settings/backup',
          builder: (_, __) {
            route = '/settings/backup';
            return const Scaffold(body: Text('backup'));
          },
        ),
      ],
    );
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(t);
    return c;
  }

  // FR-25-21, FR-25-23, FR-25-22
  testWidgets('timeout, lock now and screenshot block', (t) async {
    final c = await pump(t);
    expect(find.byKey(const Key('auto-lock-dropdown')), findsOneWidget);
    await t.tap(find.byKey(const Key('auto-lock-dropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('5 min').last);
    await settle(t);
    expect(
      await t.runAsync(
        () => env.settings.read(SecuritySettings.autoLockMinutes),
      ),
      5,
    );

    await t.tap(find.byKey(const Key('block-screenshots-switch')));
    await settle(t);
    expect(
      await t
          .runAsync(() => env.settings.read(SecuritySettings.blockScreenshots)),
      isTrue,
    );

    c.read(lockControllerProvider.notifier).markUnlocked();
    await t.tap(find.byKey(const Key('lock-now')));
    await t.pump();
    expect(c.read(lockControllerProvider).status, LockStatus.locked);
  });

  testWidgets('timeout and lock now only show with the lock on', (t) async {
    await pump(t, lock: false);
    expect(find.byKey(const Key('auto-lock-dropdown')), findsNothing);
    expect(find.byKey(const Key('lock-now')), findsNothing);
    expect(find.byKey(const Key('block-screenshots-switch')), findsOneWidget);
  });

  // FR-25-26
  testWidgets('erase needs the typed word, then wipes everything', (t) async {
    await t.runAsync(() => env.ingest(parsed()));
    await pump(t);
    expect(await t.runAsync(() => env.count('transactions')), 1);
    await t.tap(find.byKey(const Key('security-erase-all')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('erase-continue')));
    await t.pumpAndSettle();
    TextButton confirm() =>
        t.widget<TextButton>(find.byKey(const Key('security-erase-confirm')));
    expect(confirm().onPressed, isNull);
    await t.enterText(find.byKey(const Key('erase-word')), 'erase now');
    await t.pump();
    expect(confirm().onPressed, isNull);
    await t.enterText(find.byKey(const Key('erase-word')), 'ERASE');
    await t.pump();
    expect(confirm().onPressed, isNotNull);
    await t.tap(find.byKey(const Key('security-erase-confirm')));
    await settle(t);
    expect(await t.runAsync(() => env.count('transactions')), 0);
    expect(await t.runAsync(() => env.count('accounts')), 0);
    expect(pw.items, isEmpty);
    expect(ids.removed, [7]);
    expect(creds.wiped, isTrue);
  });

  testWidgets('cancel keeps data; export first opens the backup screen',
      (t) async {
    await t.runAsync(() => env.ingest(parsed()));
    await pump(t);
    await t.tap(find.byKey(const Key('security-erase-all')));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(await t.runAsync(() => env.count('transactions')), 1);

    await t.tap(find.byKey(const Key('security-erase-all')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('erase-export-first')));
    await t.pumpAndSettle();
    expect(route, '/settings/backup');
    expect(await t.runAsync(() => env.count('transactions')), 1);
  });
}
