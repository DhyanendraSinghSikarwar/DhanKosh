import 'package:flutter/material.dart';

/// Placeholder screen for: Portfolio & Net Worth.
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Portfolio & Net Worth placeholder',
          key: Key('portfolio_placeholder'),
        ),
      ),
    );
  }
}
