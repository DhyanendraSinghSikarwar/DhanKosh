import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';

/// Keeps the SMS pipeline in step with the app: on start and on every resume
/// it re-reads SMS access, drains queued messages and refreshes the UI state
/// (FR-01-09, FR-02-06); once onboarding is done it asks for notifications
/// once (FR-01-14).
class AppLifecycleGate extends ConsumerStatefulWidget {
  /// Wraps [child].
  const AppLifecycleGate({required this.child, super.key});

  /// The app.
  final Widget child;

  @override
  ConsumerState<AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends ConsumerState<AppLifecycleGate>
    with WidgetsBindingObserver {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sync()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  Future<void> _sync() async {
    if (!mounted) return;
    await ref.read(smsPermissionProvider.notifier).refresh();
    if (!mounted) return;
    await ref.read(pipelineSyncProvider)();
    unawaited(ref.read(portfolioSyncProvider)());
    try {
      if (!await ref.read(onboardingGateProvider.future)) {
        await _askNotifications();
      }
    } on Object {
      // Gate unavailable.
    }
  }

  Future<void> _askNotifications() async {
    if (_asked) return;
    _asked = true;
    try {
      await ref.read(askNotificationsOnceProvider).call();
    } on Object {
      // No native side.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingGateProvider, (_, next) {
      if (next.value == false) unawaited(_askNotifications());
    });
    return widget.child;
  }
}
