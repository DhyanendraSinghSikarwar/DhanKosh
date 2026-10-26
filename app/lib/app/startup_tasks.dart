import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/core/platform_channels/notifications_channel.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// On start and every resume: refreshes the home-screen widget (FR-30-08,
/// FR-30-09) and runs the daily update check (FR-31-18). Never throws.
class StartupTasks extends ConsumerStatefulWidget {
  /// Wraps [child].
  const StartupTasks({required this.child, super.key});

  /// The app.
  final Widget child;

  @override
  ConsumerState<StartupTasks> createState() => _StartupTasksState();
}

class _StartupTasksState extends ConsumerState<StartupTasks>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_logStart('app.start'));
      _run();
    });
  }

  /// FR-35-23: version, build mode and OS only.
  Future<void> _logStart(String code) async {
    var sdk = 0;
    if (Platform.isAndroid) {
      try {
        sdk = await const NotificationsChannel().sdkInt();
      } on Object {
        sdk = 0;
      }
    }
    AppLog.instance.info(
      LogCategory.app,
      code,
      fields: {
        'version': appVersion,
        'mode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
        'os': Platform.operatingSystem,
        'sdk': sdk,
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_logStart('app.resume'));
      _run();
    }
  }

  void _run() {
    if (!mounted) return;
    try {
      _startWidget();
      unawaited(ref.read(updateControllerProvider.notifier).check());
    } on Object {
      // Background chores never break the app.
    }
  }

  /// Re-subscribes so day and month boundaries roll over (FR-30-04). Waits
  /// for onboarding to finish: there is nothing to show before that.
  void _startWidget() {
    // The widget exists on Android only (also keeps host tests timer-free).
    if (!Platform.isAndroid) return;
    final gate = ref.read(onboardingGateProvider);
    if (gate.hasValue && !gate.requireValue) {
      ref.read(widgetSyncProvider).start();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingGateProvider, (_, next) {
      if (next.hasValue && !next.requireValue) _startWidget();
    });
    return widget.child;
  }
}
