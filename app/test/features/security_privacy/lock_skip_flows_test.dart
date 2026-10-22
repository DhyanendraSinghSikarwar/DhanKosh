import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/app/di/lock_skipping_file_source.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/app/lock_gate.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class _FakeLock implements AppLockService {
  int calls = 0;
  @override
  Future<AuthAvailability> availability() async => AuthAvailability.available;
  @override
  Future<bool> authenticate() async {
    calls++;
    return true;
  }
}

class _Picker implements FileSource {
  @override
  Future<PickedFile?> pick() async =>
      PickedFile(name: 'a.csv', bytes: Uint8List(0));
}

const _secret = Key('secret-content');

// TC-25-06, FR-01-15, FR-25-06: system hops never re-lock or loop the prompt.
void main() {
  late TestEnv env;
  late _FakeLock fake;
  setUp(() {
    env = TestEnv();
    fake = _FakeLock();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(ChannelNames.permissions),
      null,
    );
    env.close();
  });

  Future<ProviderContainer> pump(WidgetTester t) async {
    await t.runAsync(() => env.settings.write(SettingKeys.appLock, true));
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
          home: LockGate(child: Scaffold(body: Text('hi', key: _secret))),
        ),
      ),
    );
    await settle(t);
    expect(find.byKey(_secret), findsOneWidget);
    return c;
  }

  /// Native side: the system UI pauses then resumes the app mid-call.
  void mockHop(WidgetTester t) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(ChannelNames.permissions),
            (call) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return switch (call.method) {
        'smsStatus' => {'granted': false, 'rationale': true},
        'requestNotifications' => true,
        _ => null,
      };
    });
  }

  Future<void> expectNoRelock(
    WidgetTester t,
    ProviderContainer c,
    Future<void> Function() flow,
  ) async {
    final before = fake.calls;
    await t.runAsync(flow);
    await settle(t);
    expect(c.read(lockControllerProvider).status, LockStatus.unlocked);
    expect(find.byKey(_secret), findsOneWidget);
    expect(fake.calls, before);
  }

  testWidgets('SMS permission request', (t) async {
    final c = await pump(t);
    mockHop(t);
    await expectNoRelock(
      t,
      c,
      () => c.read(smsPermissionRepositoryProvider).request(),
    );
    await teardownApp(t);
  });

  testWidgets('open app settings', (t) async {
    final c = await pump(t);
    mockHop(t);
    await expectNoRelock(
      t,
      c,
      () => c.read(smsPermissionRepositoryProvider).openAppSettings(),
    );
    await teardownApp(t);
  });

  testWidgets('notification permission', (t) async {
    final c = await pump(t);
    mockHop(t);
    await expectNoRelock(
      t,
      c,
      () => c.read(notificationPermissionProvider).request(),
    );
    await teardownApp(t);
  });

  testWidgets('file picker decorator', (t) async {
    final c = await pump(t);
    final src = LockSkippingFileSource(_Picker(), c.read(lockSkipperProvider));
    await expectNoRelock(t, c, () async {
      final f = src.pick();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await f;
    });
    await teardownApp(t);
  });

  testWidgets('without skip a hop relocks (control)', (t) async {
    final c = await pump(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(c.read(lockControllerProvider).status, LockStatus.locked);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await teardownApp(t);
  });
}
