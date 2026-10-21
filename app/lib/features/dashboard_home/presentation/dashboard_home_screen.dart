import 'package:flutter/material.dart';

/// Placeholder screen for: Dashboard (Home).
class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
          child: Text('Dashboard (Home) placeholder',
              key: Key('dashboard_home_placeholder'))),
    );
  }
}
