import 'package:flutter/material.dart';

/// Placeholder screen for: Profile.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Profile placeholder', key: Key('profile_placeholder')),
      ),
    );
  }
}
