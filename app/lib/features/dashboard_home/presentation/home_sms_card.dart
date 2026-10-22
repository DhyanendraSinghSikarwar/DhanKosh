import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/shared/widgets/sms_permission_card.dart';

/// "Read bank SMS" ask on Home: only while SMS access is missing and the
/// prompt was not dismissed; "Not now" hides it for good (FR-01-13).
class HomeSmsCard extends ConsumerWidget {
  /// Creates the card.
  const HomeSmsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perm = ref.watch(smsPermissionProvider).value;
    final dismissed = ref.watch(_dismissedProvider).value ?? true;
    if (perm == null || perm.granted || dismissed) {
      return const SizedBox.shrink();
    }
    final n = ref.read(smsPermissionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SmsPermissionCard(
        blocked: perm.blocked,
        onAllow: () =>
            unawaited(perm.blocked ? n.openAppSettings() : n.request()),
        onNotNow: () => unawaited(n.dismissPrompt()),
      ),
    );
  }
}

final StreamProvider<bool> _dismissedProvider =
    StreamProvider.autoDispose<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.smsPromptDismissed),
);
