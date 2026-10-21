import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_providers.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/sms_permission_card.dart';

/// Data source "Bank SMS": status, toggle, scan now and last scan
/// (FR-26-03, FR-02-15).
class BankSmsCard extends ConsumerWidget {
  /// Creates the card.
  const BankSmsCard({super.key});

  static String _ago(int ms) {
    if (ms <= 0) return 'never';
    final d =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perm = ref.watch(smsPermissionProvider).value;
    final granted = perm?.granted ?? false;
    final enabled = ref.watch(smsEnabledProvider).value ?? true;
    final scan = ref.watch(scanControllerProvider);
    final lastAt = ref.watch(lastScanAtProvider).value ?? 0;
    final last = ref.watch(lastScanResultProvider).value ?? '';
    final text = Theme.of(context).textTheme;
    final p = scan.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (perm != null && !granted) ...[
          SmsPermissionCard(
            blocked: perm.blocked,
            onAllow: () {
              final n = ref.read(smsPermissionProvider.notifier);
              unawaited(perm.blocked ? n.openAppSettings() : n.request());
            },
          ),
          const SizedBox(height: 12),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Bank SMS', style: text.titleMedium),
                  ),
                  Text(
                    granted ? 'Allowed' : 'Not allowed',
                    key: const Key('sms-status'),
                    style: text.labelMedium,
                  ),
                ],
              ),
              SwitchListTile(
                key: const Key('sms-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Read new bank SMS'),
                value: enabled,
                onChanged: (v) =>
                    ref.read(smsEngineProvider).setEnabled(enabled: v),
              ),
              Row(
                children: [
                  FilledButton.tonal(
                    key: const Key('scan-now'),
                    onPressed: granted && !scan.running
                        ? () =>
                            ref.read(scanControllerProvider.notifier).scanNow()
                        : null,
                    child: const Text('Scan now'),
                  ),
                  const SizedBox(width: 12),
                  if (scan.running)
                    Expanded(
                      child: Text(
                        key: const Key('scan-progress'),
                        p == null
                            ? 'Scanning...'
                            : '${p.scanned} read, ${p.found} found',
                        style: text.bodySmall,
                      ),
                    ),
                ],
              ),
              if (scan.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  scan.message!,
                  key: const Key('scan-result'),
                  style: text.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Last scan: ${_ago(lastAt)}${last.isEmpty ? '' : '. $last'}',
                key: const Key('last-scan'),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Provides the key used by tests to find the masking switch.
const hideAmountsKey = Key('hide-amounts');

/// Writes the masking setting.
Future<void> setHideAmounts(WidgetRef ref, {required bool value}) =>
    ref.read(settingsRepositoryProvider).write(SettingKeys.hideAmounts, value);
