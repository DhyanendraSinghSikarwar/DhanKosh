import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/alerts_providers.dart';

/// Opened by a notification button (`/alert-action?a=...`): runs the action
/// once, then returns home (FR-21-03, FR-21-10).
class AlertActionScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [query].
  const AlertActionScreen({required this.query, super.key});

  /// Route query parameters.
  final Map<String, String> query;

  @override
  ConsumerState<AlertActionScreen> createState() => _AlertActionScreenState();
}

class _AlertActionScreenState extends ConsumerState<AlertActionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      await ref.read(alertActionHandlerProvider).handle(widget.query);
    } on Object {
      // A failed action just returns home.
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
