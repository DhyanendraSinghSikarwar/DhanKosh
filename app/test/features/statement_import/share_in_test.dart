import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/device_hooks.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/app/di/share_in_providers.dart';
import 'package:hisaab/app/router.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/domain/screen_guard.dart';
import 'package:hisaab/features/security_privacy/domain/security_settings.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/statement_import/data/channel_shared_file_source.dart';
import 'package:hisaab/features/statement_import/domain/shared_file_source.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class _Src implements SharedFileSource {
  _Src(this.file);
  PickedFile? file;
  @override
  Future<PickedFile?> take() async {
    final f = file;
    file = null;
    return f;
  }
}

class _Guard implements ScreenGuard {
  final calls = <bool>[];
  @override
  Future<void> setBlocked({required bool blocked}) async => calls.add(blocked);
}

class _Lock implements AppLockService {
  @override
  Future<AuthAvailability> availability() async => AuthAvailability.available;
  @override
  Future<bool> authenticate() async => false;
}

const _channel = MethodChannel('com.hisaab/alerts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChannelSharedFileSource (FR-05-26)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('share_in'));
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      dir.deleteSync(recursive: true);
    });

    void answer(Object? Function(MethodCall) f) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, (c) async => f(c));

    test('reads the copied file once and deletes the cache copy', () async {
      final f = File('${dir.path}/stmt.pdf')
        ..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      var calls = 0;
      answer((c) {
        expect(c.method, 'takeSharedFile');
        return calls++ == 0 ? f.path : null;
      });
      final got = await const ChannelSharedFileSource().take();
      expect(got!.name, 'stmt.pdf');
      expect(got.bytes, [1, 2, 3]);
      expect(f.existsSync(), isFalse);
      expect(await const ChannelSharedFileSource().take(), isNull);
    });

    test('nothing waiting, missing file or native error give null', () async {
      answer((_) => null);
      expect(await const ChannelSharedFileSource().take(), isNull);
      answer((_) => '${dir.path}/gone.csv');
      expect(await const ChannelSharedFileSource().take(), isNull);
      answer((_) => throw PlatformException(code: 'boom'));
      expect(await const ChannelSharedFileSource().take(), isNull);
    });
  });

  group('DeviceHooks', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    Future<(ProviderContainer, GoRouter, _Guard)> pump(
      WidgetTester t, {
      required bool lock,
      required _Src src,
    }) async {
      await t.runAsync(() => env.settings.write(SettingKeys.appLock, lock));
      final guard = _Guard();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('home')),
          GoRoute(path: '/statements', builder: (_, __) => const Text('stm')),
        ],
      );
      final c = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          appLockServiceProvider.overrideWithValue(_Lock()),
          sharedFileSourceProvider.overrideWithValue(src),
          screenGuardProvider.overrideWithValue(guard),
          routerProvider.overrideWithValue(router),
        ],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => DeviceHooks(child: child!),
          ),
        ),
      );
      await settle(t);
      return (c, router, guard);
    }

    // FR-05-26
    testWidgets('no lock: file goes to the inbox and Statements opens',
        (t) async {
      final file = PickedFile(name: 'a.pdf', bytes: Uint8List(2));
      final (c, _, _) = await pump(t, lock: false, src: _Src(file));
      expect(c.read(sharedInboxProvider)?.name, 'a.pdf');
      expect(find.text('stm'), findsOneWidget);
    });

    // FR-05-27
    testWidgets('locked: nothing is imported until unlock', (t) async {
      final file = PickedFile(name: 'a.csv', bytes: Uint8List(2));
      final (c, _, _) = await pump(t, lock: true, src: _Src(file));
      expect(c.read(sharedInboxProvider), isNull);
      expect(find.text('home'), findsOneWidget);
      expect(find.text('stm'), findsNothing);
      c.read(lockControllerProvider.notifier).markUnlocked();
      await settle(t);
      expect(c.read(sharedInboxProvider)?.name, 'a.csv');
      expect(find.text('stm'), findsOneWidget);
    });

    testWidgets('no shared file: stays put', (t) async {
      final (c, _, _) = await pump(t, lock: false, src: _Src(null));
      expect(c.read(sharedInboxProvider), isNull);
      expect(find.text('home'), findsOneWidget);
      expect(find.text('stm'), findsNothing);
    });

    // FR-25-23
    testWidgets('screenshot block is applied at start and on toggle',
        (t) async {
      final (_, _, guard) = await pump(t, lock: false, src: _Src(null));
      expect(guard.calls, [false]);
      await t.runAsync(
        () => env.settings.write(SecuritySettings.blockScreenshots, true),
      );
      await settle(t);
      expect(guard.calls.last, isTrue);
    });
  });
}
