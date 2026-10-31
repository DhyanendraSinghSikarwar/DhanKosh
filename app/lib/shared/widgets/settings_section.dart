import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// A titled group of rows in one card, with hairlines between rows.
class SettingsSection extends StatelessWidget {
  /// Creates a section. [leading] widgets (compact cards) sit above the rows.
  const SettingsSection({
    required this.title,
    required this.children,
    this.leading = const [],
    super.key,
  });

  /// Section header.
  final String title;

  /// Rows, drawn inside one card.
  final List<Widget> children;

  /// Cards drawn between the header and the rows.
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            title,
            key: Key('section-$title'),
            style: theme.textTheme.titleSmall,
          ),
        ),
        for (final w in leading)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
        if (children.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
      ],
    );
  }
}
