import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/erase_all.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/domain/security_settings.dart';
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

  /// FR-25-26: export offer, then a typed word, then erase.
  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final step = await showDialog<_EraseStep>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text(
          'Removes transactions, accounts, saved passwords and settings from '
          'this phone. This cannot be undone. Export an encrypted backup '
          'first to keep a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('erase-export-first'),
            onPressed: () => Navigator.pop(c, _EraseStep.export),
            child: const Text('Export first'),
          ),
          TextButton(
            key: const Key('erase-continue'),
            onPressed: () => Navigator.pop(c, _EraseStep.erase),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (step == null || !context.mounted) return;
    if (step == _EraseStep.export) {
      await context.push<void>('/settings/backup');
      return;
    }
    final typed = await showDialog<bool>(
      context: context,
      builder: (_) => const _TypeToConfirmDialog(),
    );
    if (typed ?? false) {
      await eraseAllData(ref);
      ref.read(lockControllerProvider.notifier).markUnlocked();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All data erased')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockEnabledProvider).value ?? false;
    final hide = ref.watch(hideAmountsProvider).value ?? true;
    final avail = ref.watch(authAvailabilityProvider).value;
    final timeout = ref.watch(autoLockMinutesProvider).value ?? 0;
    final block = ref.watch(blockScreenshotsProvider).value ?? false;
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
          if (lock) ...[
            ListTile(
              key: const Key('auto-lock-timeout'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Lock after'),
              subtitle: const Text('Time away before the app locks again'),
              trailing: DropdownButton<int>(
                key: const Key('auto-lock-dropdown'),
                value: SecuritySettings.timeoutChoices.contains(timeout)
                    ? timeout
                    : 0,
                items: [
                  for (final m in SecuritySettings.timeoutChoices)
                    DropdownMenuItem(
                      value: m,
                      child: Text(SecuritySettings.timeoutLabel(m)),
                    ),
                ],
                onChanged: (v) => ref
                    .read(settingsRepositoryProvider)
                    .write(SecuritySettings.autoLockMinutes, v ?? 0),
              ),
            ),
            ListTile(
              key: const Key('lock-now'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock now'),
              onTap: () => ref.read(lockControllerProvider.notifier).lockNow(),
            ),
          ],
          SwitchListTile(
            key: const Key('block-screenshots-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Block screenshots'),
            subtitle: const Text('Also hides the app in recent apps'),
            value: block,
            onChanged: (v) => ref
                .read(settingsRepositoryProvider)
                .write(SecuritySettings.blockScreenshots, v),
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
            key: const Key('security-erase-all'),
            onPressed: () => _erase(context, ref),
            child: const Text('Erase all data'),
          ),
        ],
      ),
    );
  }
}

enum _EraseStep { export, erase }

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  static const word = 'ERASE';
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Type ERASE to confirm'),
        content: TextField(
          key: const Key('erase-word'),
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'ERASE'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('security-erase-confirm'),
            onPressed: _c.text.trim() == word
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Erase everything'),
          ),
        ],
      );
}
