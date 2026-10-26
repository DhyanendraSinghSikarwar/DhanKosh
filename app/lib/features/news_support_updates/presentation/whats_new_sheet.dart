import 'package:flutter/material.dart';

/// One-time "What's new in x.y.z" sheet (FR-31-36).
class WhatsNewSheet extends StatelessWidget {
  /// Creates the sheet for [version] with note lines [points].
  const WhatsNewSheet({required this.version, required this.points, super.key});

  /// Installed version.
  final String version;

  /// Cleaned note lines.
  final List<String> points;

  /// Shows the sheet; returns when dismissed.
  static Future<void> show(
    BuildContext context, {
    required String version,
    required List<String> points,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => WhatsNewSheet(version: version, points: points),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What's new in $version",
                key: const Key('whats-new-title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final p in points) Text('• $p')],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('whats-new-done'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
}
