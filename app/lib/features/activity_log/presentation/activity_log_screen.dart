import 'package:flutter/material.dart';

/// Placeholder screen for: Activity Log.
class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Activity Log placeholder',
          key: Key('activity_log_placeholder'),
        ),
      ),
    );
  }
}
