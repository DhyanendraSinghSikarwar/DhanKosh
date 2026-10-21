import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/router.dart';

/// On start and every resume: runs the alert checks (FR-21-13) and opens the
/// screen of the alert the user tapped (FR-21-15). Never throws.
class AlertsLifecycle extends ConsumerStatefulWidget {
  /// Wraps [child].
  const AlertsLifecycle({required this.child, super.key});

  /// The app.
  final Widget child;

  @override
  ConsumerState<AlertsLifecycle> createState() => _AlertsLifecycleState();
}

class _AlertsLifecycleState extends ConsumerState<AlertsLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    try {
      final route = await ref.read(alertPosterProvider).takeLaunchRoute();
      if (route != null && mounted) _open(ref.read(routerProvider), route);
      if (!mounted) return;
      await ref.read(alertsEngineProvider).run();
    } on Object {
      // Alerts never break the app.
    }
  }

  void _open(GoRouter router, String route) {
    final match = router.configuration.findMatch(Uri.parse(route));
    router.go(match.isError ? '/home' : route);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
