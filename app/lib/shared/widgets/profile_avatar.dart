import 'dart:io';

import 'package:flutter/material.dart';

/// Round profile picture: the saved photo, else the name's initials
/// (FR-27-20). Pure widget: pass `UserProfile.name` and `photoPath`.
class ProfileAvatar extends StatelessWidget {
  /// Creates the avatar.
  const ProfileAvatar({
    this.name,
    this.photoPath,
    this.radius = 20,
    super.key,
  });

  /// Full name, for the initials fallback.
  final String? name;

  /// Path of the saved photo; null or empty shows initials.
  final String? photoPath;

  /// Circle radius.
  final double radius;

  /// One or two capital letters from [name]; `H` when empty.
  static String initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return 'H';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = photoPath;
    final file = path == null || path.isEmpty ? null : File(path);
    final has = file != null && file.existsSync();
    return CircleAvatar(
      key: const Key('profile-avatar'),
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      backgroundImage: has ? FileImage(file) : null,
      child: has
          ? null
          : Text(initials(name), style: TextStyle(fontSize: radius * 0.8)),
    );
  }
}
