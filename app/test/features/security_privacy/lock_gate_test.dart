import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/app/lock_gate.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/features/security_privacy/presentation/security_privacy_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class FakeLock implements AppLockService {
  FakeLock({this.ok = true, this.avail = AuthAvailability.available});
  bool ok;
  AuthAvailability avail;
  int calls = 0;
  @override
  Future<AuthAvailability> availability() async => avail;
  @override
  Future<bool> authenticate() async {
    calls++;
    return ok;
  }
}

const _secret = Key('secret-content');

void main() {
  late TestEnv env;
  late FakeLock fake;
  setUp(() {
    env = TestEnv();
    fake = FakeLock(ok: false);
  });
  tearDown(() => env.close());

  Future<ProviderContainer> pump(WidgetTester t, {required bool lock}) async {
    await t.runAsync(() => env.settings.write(SettingKeys.appLock, lock));
    final c = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(env.settings),
        appLockServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: LockGate(child: Scaffold(body: Text('hello', key: _secret))),
        ),
      ),
    );
    await settle(t);
    return c;
  }

  testWidgets('no lock: content shown, no prompt', (t) async {
    await pump(t, lock: false);
    expect(find.byKey(_secret), findsOneWidget);
    expect(fake.calls, 0);
    await teardownApp(t);
  });

  testWidgets('cold start with lock hides content, prompts (TC-25-09/11)',
      (t) async {
    await pump(t, lock: true);
    expect(find.byKey(_secret), findsNothing);
    expect(find.text('DhanKosh is locked'), findsOneWidget);
    expect(fake.calls, 1);
    // Cancelled prompt stays locked; Unlock re-fires it.
    await t.tap(find.byKey(const Key('lock-unlock')));
    await settle(t);
    expect(fake.calls, 2);
    expect(find.byKey(_secret), findsNothing);
    fake.ok = true;
    await t.tap(find.byKey(const Key('lock-unlock')));
    await settle(t);
    expect(find.byKey(_secret), findsOneWidget);
    expect(find.byKey(const Key('lock-overlay')), findsNothing);
    await teardownApp(t);
  });

  testWidgets(
      'locks after pause, inactive does not; unlock on resume '
      '(TC-25-07/12)', (t) async {
    fake.ok = true;
    final c = await pump(t, lock: true);
    expect(find.byKey(_secret), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    expect(find.byKey(_secret), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    // Frames are off while paused; the state flips at once.
    expect(c.read(lockControllerProvider).status, LockStatus.locked);
    final before = fake.calls;
    fake.ok = false;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(fake.calls, before + 1);
    expect(find.byKey(_secret), findsNothing);
    expect(find.text('DhanKosh is locked'), findsOneWidget);
    fake.ok = true;
    await t.tap(find.byKey(const Key('lock-unlock')));
    await settle(t);
    expect(find.byKey(_secret), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('skipNextLock holds once, then locks (TC-25-06)', (t) async {
    fake.ok = true;
    final c = await pump(t, lock: true);
    c.read(lockControllerProvider.notifier).skipNextLock();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(find.byKey(_secret), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(c.read(lockControllerProvider).status, LockStatus.locked);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await teardownApp(t);
  });

  testWidgets(
      'security screen: lock switch and unavailable reason '
      '(TC-25-08/13)', (t) async {
    fake.avail = AuthAvailability.noneEnrolled;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          appLockServiceProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: SecurityPrivacyScreen()),
      ),
    );
    await settle(t);
    expect(find.text('Set a screen lock on this phone first'), findsOneWidget);
    final sw =
        t.widget<SwitchListTile>(find.byKey(const Key('app-lock-switch')));
    expect(sw.onChanged, isNull);
    expect(find.text('Erase all data'), findsOneWidget);
    expect(
      find.text('Your data never leaves this phone. No servers, no tracking.'),
      findsOneWidget,
    );
    await teardownApp(t);
  });
}
