import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/settings_data_sources/presentation/bank_sms_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/history_days_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/paste_sms_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_providers.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// Opens [child] (one of the capture cards) in a scrollable bottom sheet.
Future<void> showCaptureSheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(c).bottom,
          ),
          child: child,
        ),
      ),
    );

String _ago(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// "Bank SMS" row: live state, opens the permission, switch and scan card
/// (FR-26-03, FR-26-34).
class BankSmsRow extends ConsumerWidget {
  /// Creates the row.
  const BankSmsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(smsPermissionProvider).value?.granted ?? false;
    final enabled = ref.watch(smsEnabledProvider).value ?? true;
    final lastAt = ref.watch(lastScanAtProvider).value ?? 0;
    final live = enabled ? 'Live capture on' : 'Live capture off';
    final scan = lastAt > 0 ? ', last scan ${_ago(lastAt)}' : '';
    return SettingsRow(
      key: const Key('bank-sms-row'),
      badge: AppIcons.sms,
      title: 'Bank SMS',
      subtitle: granted ? '$live$scan' : 'Not allowed',
      onTap: () => showCaptureSheet(context, const BankSmsCard()),
    );
  }
}

/// "Paste SMS" row: opens the paste form (FR-26-26).
class PasteSmsRow extends StatelessWidget {
  /// Creates the row.
  const PasteSmsRow({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('paste-sms-row'),
        badge: AppIcons.pasteSms,
        title: 'Paste SMS',
        subtitle: 'Add a message by hand',
        onTap: () => showCaptureSheet(context, const PasteSmsCard()),
      );
}

/// "History window" row: opens the slider and presets (FR-26-30).
class HistoryDaysRow extends ConsumerWidget {
  /// Creates the row.
  const HistoryDaysRow({super.key});

  /// Friendly span: `3 months` for 90, else days.
  static String span(int days) => switch (days) {
        30 => '1 month',
        90 => '3 months',
        180 => '6 months',
        365 => '1 year',
        _ => '$days days',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(historyDaysProvider).value ?? 90;
    return SettingsRow(
      key: const Key('history-row'),
      badge: AppIcons.history,
      title: 'History window',
      subtitle: 'Scan last ${span(days)}',
      onTap: () => showCaptureSheet(context, const HistoryDaysCard()),
    );
  }
}

/// "Notification access" row: opens the payment-app card.
class NotificationAccessRow extends StatelessWidget {
  /// Creates the row around the composed [card].
  const NotificationAccessRow({required this.card, super.key});

  /// Payment-app notifications card (F-04).
  final Widget card;

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('notification-access-row'),
        badge: AppIcons.notifications,
        title: 'Notification access',
        subtitle: 'Payment-app alerts',
        onTap: () => showCaptureSheet(context, card),
      );
}

/// Compact banner shown at the top of More while SMS is not allowed.
class SmsAccessBanner extends ConsumerWidget {
  /// Creates the banner.
  const SmsAccessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perm = ref.watch(smsPermissionProvider).value;
    if (perm == null || perm.granted) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        key: const Key('sms-banner'),
        child: Row(
          children: [
            const IconBadge(AppIcons.sms),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Read bank SMS', style: text.bodyLarge),
                  Text(
                    perm.blocked
                        ? 'Open App settings to allow SMS'
                        : 'Only bank senders, only on this phone',
                    key: const Key('sms-card-body'),
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('grant-sms'),
              onPressed: () {
                final n = ref.read(smsPermissionProvider.notifier);
                unawaited(perm.blocked ? n.openAppSettings() : n.request());
              },
              child: Text(perm.blocked ? 'Settings' : 'Allow'),
            ),
          ],
        ),
      ),
    );
  }
}
