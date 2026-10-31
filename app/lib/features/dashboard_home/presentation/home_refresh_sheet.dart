import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/home_sync_provider.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

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
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          key: const Key('home_refresh_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    finished ? 'Up to date' : 'Fetching new transactions',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('home_refresh_close'),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                key: const Key('home_refresh_progress'),
                height: 10,
                color: scheme.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: s.progress.clamp(0, 1).toDouble(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [scheme.primaryContainer, scheme.primary],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    finished ? 'Finished' : 'Reading SMS and email',
                    style: MockText.small(context),
                  ),
                ),
                Text(
                  '$pct%',
                  style: MockText.small(context, color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Step(
              key: const Key('home_refresh_sms'),
              label: 'SMS',
              detail: s.scanned > 0 ? 'Reading ${s.scanned} messages' : 'Inbox',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.resultLine,
                  key: const Key('home_refresh_result'),
                  style: const TextStyle(fontSize: 13),
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
                'Everything is read on this phone. Nothing is uploaded.',
                style: MockText.small(context),
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
    final scheme = Theme.of(context).colorScheme;
    final running = !done && fraction > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: done
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 14, color: scheme.onPrimary),
                  )
                : running
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.outlineVariant,
                            width: 2,
                          ),
                        ),
                      ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MockText.body(context)),
                Text(detail, style: MockText.small(context)),
              ],
            ),
          ),
          Text(
            '${(fraction * 100).round()}%',
            style: MockText.small(context),
          ),
        ],
      ),
    );
  }
}
