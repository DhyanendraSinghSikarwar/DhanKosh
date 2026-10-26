import 'dart:async';

import 'package:flutter/widgets.dart' hide LockState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/app/di/share_in_providers.dart';
import 'package:hisaab/app/router.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

/// Native hooks on start and resume: applies the screenshot block (FR-25-23)
/// and hands a file shared from another app to the Statements screen once the
/// app is unlocked (FR-05-26, FR-05-27). Never throws.
class DeviceHooks extends ConsumerStatefulWidget {
  /// Wraps [child].
  const DeviceHooks({required this.child, super.key});

  /// The app.
  final Widget child;

  @override
  ConsumerState<DeviceHooks> createState() => _DeviceHooksState();
}

class _DeviceHooksState extends ConsumerState<DeviceHooks>
    with WidgetsBindingObserver {
  PickedFile? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref
      ..listenManual<AsyncValue<bool>>(
        blockScreenshotsProvider,
        (_, next) {
          if (!next.hasValue) return;
          unawaited(
            ref.read(screenGuardProvider).setBlocked(blocked: next.value!),
          );
        },
        fireImmediately: true,
      )
      ..listenManual<LockState>(lockControllerProvider, (_, __) => _deliver())
      ..listenManual<AsyncValue<bool>>(
        appLockEnabledProvider,
        (_, __) => _deliver(),
      );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_take()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_take());
  }

  Future<void> _take() async {
    try {
      final f = await ref.read(sharedFileSourceProvider).take();
      if (f == null || !mounted) return;
      _pending = f;
      _deliver();
    } on Object {
      // Share-in never breaks the app.
    }
  }

  /// FR-05-27: nothing is imported while the lock is up.
  void _deliver() {
    final f = _pending;
    if (f == null || !mounted) return;
    final enabled = ref.read(appLockEnabledProvider);
    if (!enabled.hasValue) return;
    if ((enabled.value ?? false) &&
        ref.read(lockControllerProvider).needsAuth) {
      return;
    }
    _pending = null;
    ref.read(sharedInboxProvider.notifier).put(f);
    final router = ref.read(routerProvider);
    final at = router.routerDelegate.currentConfiguration.last.matchedLocation;
    if (at != '/statements') unawaited(router.push<void>('/statements'));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
