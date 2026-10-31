import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// SMS access ask: rationale, or the restricted-settings guidance when Android
/// refuses the prompt (FR-01-10, FR-01-11).
class SmsPermissionCard extends StatelessWidget {
  /// Creates the card.
  const SmsPermissionCard({
    required this.blocked,
    required this.onAllow,
    this.onNotNow,
    this.compact = false,
    super.key,
  });

  /// Only App settings can grant now.
  final bool blocked;

  /// Allow SMS access, or open App settings when [blocked].
  final VoidCallback onAllow;

  /// Hides the card; null hides the button.
  final VoidCallback? onNotNow;

  /// One-row layout (Home): badge, two lines, Allow and a close icon.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = blocked
        ? "Android didn't show the prompt. Open App settings, then "
            'Permissions, SMS, Allow. If SMS is greyed out, tap the '
            'menu at the top right of App info and choose Allow '
            'restricted settings.'
        : 'Reads SMS only from bank senders, on this phone. '
            'Nothing is uploaded.';
    if (compact) {
      return Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              const IconBadge(AppIcons.sms, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Read bank SMS',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      body,
                      key: const Key('sms-card-body'),
                      maxLines: blocked ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('grant-sms'),
                onPressed: onAllow,
                child: Text(blocked ? 'Open settings' : 'Allow SMS'),
              ),
              if (onNotNow != null)
                IconButton(
                  key: const Key('sms-not-now'),
                  tooltip: 'Not now',
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                  onPressed: onNotNow,
                ),
            ],
          ),
        ),
      );
    }
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sms_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Read bank SMS',
                  style: text.titleMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              blocked
                  ? "Android didn't show the prompt. Open App settings, then "
                      'Permissions, SMS, Allow. If SMS is greyed out, tap the '
                      'menu at the top right of App info and choose Allow '
                      'restricted settings.'
                  : 'Reads SMS only from bank senders, on this phone. '
                      'Nothing is uploaded.',
              key: const Key('sms-card-body'),
              style: text.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const Key('grant-sms'),
                  onPressed: onAllow,
                  child: Text(blocked ? 'Open App settings' : 'Allow SMS'),
                ),
                if (onNotNow != null)
                  TextButton(
                    key: const Key('sms-not-now'),
                    onPressed: onNotNow,
                    child: const Text('Not now'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
