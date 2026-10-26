// Setting several test hooks one per line reads clearer than a cascade.
// ignore_for_file: cascade_invocations
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';

class _Lock implements AppLockService {
  bool ok = false;
  @override
  Future<AuthAvailability> availability() async => AuthAvailability.available;
  @override
  Future<bool> authenticate() async => ok;
}

void main() {
  late ProviderContainer c;
  late LockController ctl;
  late _Lock svc;
  late DateTime clock;

  setUp(() {
    svc = _Lock();
    clock = DateTime(2026, 10, 26, 10);
    c = ProviderContainer(
      overrides: [appLockServiceProvider.overrideWithValue(svc)],
    );
    ctl = c.read(lockControllerProvider.notifier);
    ctl.now = () => clock;
    ctl.markUnlocked();
  });
  tearDown(() => c.dispose());

  LockStatus status() => c.read(lockControllerProvider).status;

  // FR-25-21
  group('auto-lock timeout', () {
    test('0 locks as soon as the app leaves', () {
      ctl.onLifecycle(AppLifecycleState.paused, enabled: true);
      expect(status(), LockStatus.locked);
    });

    test('5 min: short absence keeps unlocked, long absence locks on resume',
        () {
      ctl.onLifecycle(
        AppLifecycleState.paused,
        enabled: true,
        timeoutMinutes: 5,
      );
      expect(status(), LockStatus.unlocked);
      clock = clock.add(const Duration(minutes: 2));
      ctl.onLifecycle(
        AppLifecycleState.resumed,
        enabled: true,
        timeoutMinutes: 5,
      );
      expect(status(), LockStatus.unlocked);

      ctl.onLifecycle(
        AppLifecycleState.paused,
        enabled: true,
        timeoutMinutes: 5,
      );
      clock = clock.add(const Duration(minutes: 5));
      ctl.onLifecycle(
        AppLifecycleState.resumed,
        enabled: true,
        timeoutMinutes: 5,
      );
      expect(status(), LockStatus.locked);
    });

    test('hidden then paused counts from the first event', () {
      ctl
        ..onLifecycle(
          AppLifecycleState.hidden,
          enabled: true,
          timeoutMinutes: 1,
        )
        ..now = () => clock.add(const Duration(seconds: 50));
      ctl.onLifecycle(
        AppLifecycleState.paused,
        enabled: true,
        timeoutMinutes: 1,
      );
      ctl.now = () => clock.add(const Duration(seconds: 65));
      ctl.onLifecycle(
        AppLifecycleState.resumed,
        enabled: true,
        timeoutMinutes: 1,
      );
      expect(status(), LockStatus.locked);
    });

    test('a skip flag still protects a file-picker hop', () {
      ctl
        ..skipNextLock()
        ..onLifecycle(AppLifecycleState.paused, enabled: true);
      expect(status(), LockStatus.unlocked);
    });

    test('lock disabled never locks', () {
      ctl.onLifecycle(AppLifecycleState.paused, enabled: false);
      expect(status(), LockStatus.unlocked);
    });
  });

  // FR-25-22
  test('lockNow locks at once', () {
    ctl.lockNow();
    expect(status(), LockStatus.locked);
  });

  // FR-25-24, FR-25-25
  group('failed attempts', () {
    test('delay after 5 failures, doubling, capped', () async {
      ctl.lockNow();
      for (var i = 0; i < 4; i++) {
        await ctl.unlock();
      }
      expect(ctl.waitSeconds(), 0);
      await ctl.unlock();
      expect(c.read(lockControllerProvider).failures, 5);
      expect(ctl.waitSeconds(), 30);
      // Blocked during the delay: no new attempt is counted.
      await ctl.unlock();
      expect(c.read(lockControllerProvider).failures, 5);
      clock = clock.add(const Duration(seconds: 31));
      expect(ctl.waitSeconds(), 0);
      await ctl.unlock();
      expect(ctl.waitSeconds(), 60);
      for (var i = 0; i < 10; i++) {
        clock = clock.add(const Duration(minutes: 6));
        await ctl.unlock();
      }
      expect(ctl.waitSeconds(), LockController.maxDelay.inSeconds);
    });

    test('success after 3+ failures reports the count once, counts only',
        () async {
      final seen = <int>[];
      ctl.onRecoveredAfterFailures = (n) async {
        seen.add(n);
      };
      ctl.lockNow();
      for (var i = 0; i < 3; i++) {
        await ctl.unlock();
      }
      svc.ok = true;
      await ctl.unlock();
      expect(status(), LockStatus.unlocked);
      expect(seen, [3]);
      expect(c.read(lockControllerProvider).failures, 0);
    });

    test('one or two failures raise no entry', () async {
      final seen = <int>[];
      ctl.onRecoveredAfterFailures = (n) async {
        seen.add(n);
      };
      ctl.lockNow();
      await ctl.unlock();
      svc.ok = true;
      await ctl.unlock();
      expect(seen, isEmpty);
    });
  });
}
