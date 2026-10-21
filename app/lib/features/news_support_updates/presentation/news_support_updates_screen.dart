import 'package:flutter/material.dart';

/// Placeholder screen for: News, Support & Updates.
class NewsSupportUpdatesScreen extends StatelessWidget {
  const NewsSupportUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
          child: Text('News, Support & Updates placeholder',
              key: Key('news_support_updates_placeholder'))),
    );
  }
}
