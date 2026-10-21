import 'package:flutter/material.dart';

/// Placeholder screen for: Expense Tracking & Budgets.
class ExpenseTrackingScreen extends StatelessWidget {
  const ExpenseTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
          child: Text('Expense Tracking & Budgets placeholder',
              key: Key('expense_tracking_placeholder'))),
    );
  }
}
