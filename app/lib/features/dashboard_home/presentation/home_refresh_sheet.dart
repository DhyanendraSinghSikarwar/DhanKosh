import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/home_sync_provider.dart';

/// Bottom sheet shown while Home fetches new SMS and email: determinate
/// progress, a row per source and the result line (FR-17-42).
class HomeRefreshSheet extends ConsumerWidget {
  /// Creates the sheet.
  const HomeRefreshSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeSyncProvider);
    final theme = Theme.of(context);
    final finished = s.stage == HomeSyncStage.done;
    final pct = (s.progress * 100).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          key: const Key('home_refresh_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              finished ? 'Up to date' : 'Fetching new transactions',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const Key('home_refresh_progress'),
              value: s.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    finished ? 'Finished' : 'Reading SMS and email',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text('$pct%', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            _Step(
              key: const Key('home_refresh_sms'),
              label: 'SMS',
              detail: s.scanned > 0 ? 'Read ${s.scanned} messages' : 'Inbox',
              fraction: s.smsFraction,
              done: s.stage.index > HomeSyncStage.sms.index,
            ),
            _Step(
              key: const Key('home_refresh_email'),
              label: 'Email',
              detail: 'Connected mailboxes',
              fraction: s.emailFraction,
              done: s.stage.index > HomeSyncStage.email.index,
            ),
            _Step(
              key: const Key('home_refresh_matching'),
              label: 'Matching',
              detail: 'Removing duplicates',
              fraction: s.matchFraction,
              done: finished,
            ),
            const SizedBox(height: 8),
            if (finished) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    s.resultLine,
                    key: const Key('home_refresh_result'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('home_refresh_done'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ] else
              Text(
                'Read on this phone. Nothing is uploaded.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.detail,
    required this.fraction,
    required this.done,
    super.key,
  });

  final String label;
  final String detail;
  final double fraction;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = !done && fraction > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: done
                ? Icon(
                    Icons.check_circle,
                    size: 22,
                    color: theme.colorScheme.primary,
                  )
                : running
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Icon(
                        Icons.radio_button_unchecked,
                        size: 22,
                        color: theme.colorScheme.outline,
                      ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${(fraction * 100).round()}%',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
