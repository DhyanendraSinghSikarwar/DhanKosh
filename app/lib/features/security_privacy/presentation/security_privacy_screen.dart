import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

/// Security and privacy (F-25, FR-25-16): app lock, hide amounts, short
/// privacy statements, clear all data. [hostedRows] carries rows owned by
/// other features (text size, CSV backup).
class SecurityPrivacyScreen extends ConsumerWidget {
  /// Creates the screen.
  const SecurityPrivacyScreen({this.hostedRows = const [], super.key});

  /// Rows hosted from other features, shown after Hide amounts.
  final List<Widget> hostedRows;

  static const _statements = <(IconData, String)>[
    (
      Icons.phone_android_outlined,
      'Your data never leaves this phone. No servers, no tracking.',
    ),
    (Icons.cloud_off_outlined, 'No cloud backup or device transfer.'),
    (Icons.lock_outline, 'Passwords and IDs are encrypted on this phone.'),
    (Icons.https_outlined, 'Only encrypted connections, to your own mailbox.'),
  ];

  Future<void> _setLock(WidgetRef ref, {required bool value}) async {
    await ref.read(settingsRepositoryProvider).write(
          SettingKeys.appLock,
          value,
        );
    // FR-25-07: switching on must not lock the user out at once.
    if (value) ref.read(lockControllerProvider.notifier).markUnlocked();
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text('Removes transactions and accounts on this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('security-clear-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(dataResetRepositoryProvider).clearLedger();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockEnabledProvider).value ?? false;
    final hide = ref.watch(hideAmountsProvider).value ?? true;
    final avail = ref.watch(authAvailabilityProvider).value;
    final canLock = avail == AuthAvailability.available;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Security & privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            key: const Key('app-lock-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('App lock'),
            subtitle: avail != null && !canLock
                ? const Text('Set a screen lock on this phone first')
                : const Text('Fingerprint, face or screen lock'),
            value: lock,
            onChanged: canLock || lock ? (v) => _setLock(ref, value: v) : null,
          ),
          SwitchListTile(
            key: const Key('hide-amounts-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide amounts'),
            value: hide,
            onChanged: (v) => ref
                .read(settingsRepositoryProvider)
                .write(SettingKeys.hideAmounts, v),
          ),
          ...hostedRows,
          const SizedBox(height: 16),
          Text('Privacy', style: text.titleSmall),
          for (final (icon, line) in _statements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(icon),
              title: Text(line),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('security-clear-all'),
            onPressed: () => _confirmClear(context, ref),
            child: const Text('Clear all data'),
          ),
        ],
      ),
    );
  }
}
