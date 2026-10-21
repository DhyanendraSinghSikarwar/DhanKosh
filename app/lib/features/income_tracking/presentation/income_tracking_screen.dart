import 'package:flutter/material.dart';

/// Placeholder screen for: Income Tracking.
class IncomeTrackingScreen extends StatelessWidget {
  const IncomeTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Income Tracking placeholder',
          key: Key('income_tracking_placeholder'),
        ),
      ),
    );
  }
}
