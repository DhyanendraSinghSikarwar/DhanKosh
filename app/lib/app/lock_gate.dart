import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_overlay.dart';

/// Wraps the app: while the lock is on and the session is not authenticated
/// the content is hidden behind an opaque overlay (FR-25-03). The child stays
/// mounted so navigation state survives (FR-25-05). Background workers do
/// not pass through here, so they are never blocked.
class LockGate extends ConsumerStatefulWidget {
  /// Wraps [child].
  const LockGate({required this.child, super.key});

  /// The app.
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = WidgetsBinding.instance.lifecycleState;
    _resumed = s == null || s == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _enabled => ref.read(appLockEnabledProvider).value ?? false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    ref
        .read(lockControllerProvider.notifier)
        .onLifecycle(state, enabled: _enabled);
    if (_resumed) _promptIfLocked();
  }

  void _promptIfLocked() {
    if (_enabled && ref.read(lockControllerProvider).needsAuth) {
      unawaited(ref.read(lockControllerProvider.notifier).unlock());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prompt as soon as the lock setting is known (cold start, FR-25-03).
    ref.listen(appLockEnabledProvider, (_, next) {
      if (next.value ?? false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _resumed) _promptIfLocked();
        });
      }
    });
    // Re-prompt when the app locks while in front (e.g. skip expired).
    ref.listen(lockControllerProvider, (prev, next) {
      if (prev?.status != LockStatus.locked &&
          next.status == LockStatus.locked &&
          _resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _promptIfLocked();
        });
      }
    });
    final enabled = ref.watch(appLockEnabledProvider);
    final lock = ref.watch(lockControllerProvider);
    if (!enabled.hasValue) {
      // FR-25-08: blank until the setting is known; no content flash.
      return ColoredBox(
        key: const Key('lock-splash'),
        color: Theme.of(context).colorScheme.surface,
      );
    }
    final locked = enabled.value! && lock.needsAuth;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(
          child: Offstage(
            offstage: locked,
            child: TickerMode(enabled: !locked, child: widget.child),
          ),
        ),
        if (locked)
          Positioned.fill(
            child: LockOverlay(
              failed: lock.failed,
              busy: lock.prompting,
              onUnlock: () =>
                  unawaited(ref.read(lockControllerProvider.notifier).unlock()),
            ),
          ),
      ],
    );
  }
}
