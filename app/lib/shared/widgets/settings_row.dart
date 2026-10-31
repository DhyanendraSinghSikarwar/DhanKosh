import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// One More-tab row: coloured [IconBadge], title, one-line subtitle and a
/// chevron (or a custom [trailing]).
class SettingsRow extends StatelessWidget {
  /// Creates a row.
  const SettingsRow({
    required this.badge,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    super.key,
  });

  /// Icon and tint.
  final AppIcon badge;

  /// Row title.
  final String title;

  /// One-line hint under the title.
  final String? subtitle;

  /// Replaces the chevron.
  final Widget? trailing;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Draws the title in the error colour.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            IconBadge(badge, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: destructive ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ],
        ),
      ),
    );
  }
}
