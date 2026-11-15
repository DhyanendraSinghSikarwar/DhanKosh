import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/platform_channels/folder_channel.dart';
import 'package:hisaab/features/backup_export/domain/passphrase_strength.dart';
import 'package:hisaab/features/backup_export/domain/scheduled_backup.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/ui/app_dates.dart';

/// Automatic month-wise backup (FR-24-34..34). The phone copy is always made;
/// the cloud copy only when the user allows it and picks the folder (and so
/// the Google account) in the system picker.
class AutoBackupSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const AutoBackupSection({super.key});

  @override
  ConsumerState<AutoBackupSection> createState() => _State();
}

class _Snapshot {
  const _Snapshot({
    required this.on,
    required this.localName,
    required this.drive,
    required this.driveName,
    required this.last,
    required this.result,
  });

  final bool on;
  final String localName;
  final bool drive;
  final String driveName;
  final int last;
  final String result;
}

class _State extends ConsumerState<AutoBackupSection> {
  _Snapshot? _s;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final r = ref.read(settingsRepositoryProvider);
    final s = _Snapshot(
      on: await r.read(autoBackupKey),
      localName: await r.read(autoBackupLocalNameKey),
      drive: await r.read(autoBackupDriveKey),
      driveName: await r.read(autoBackupDriveNameKey),
      last: await r.read(autoBackupLastKey),
      result: await r.read(autoBackupResultKey),
    );
    if (mounted) setState(() => _s = s);
  }

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<PickedFolder?> _pick() async {
    ref.read(lockSkipperProvider).skipNextLock();
    try {
      return await const FolderChannel().pick();
    } on Object {
      _say(t('Could not open the folder picker'));
      return null;
    }
  }

  // FR-24-34
  Future<void> _toggle({required bool on}) async {
    final settings = ref.read(settingsRepositoryProvider);
    if (!on) {
      await settings.write(autoBackupKey, false);
      await _load();
      return;
    }
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => const _PassphraseDialog(),
    );
    if (pass == null) return;
    await ref.read(secureStoreProvider).write(autoBackupPassphraseSecret, pass);
    await settings.write(autoBackupKey, true);
    await _load();
    await _now();
  }

  // FR-24-35
  Future<void> _chooseLocal() async {
    final f = await _pick();
    if (f == null) return;
    final settings = ref.read(settingsRepositoryProvider);
    await settings.write(autoBackupLocalKey, f.uri);
    await settings.write(autoBackupLocalNameKey, f.name);
    await settings.write(autoBackupManifestKey, '{}');
    await _load();
  }

  Future<void> _useAppStorage() async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.write(autoBackupLocalKey, '');
    await settings.write(autoBackupLocalNameKey, '');
    await _load();
  }

  // FR-24-36
  Future<void> _chooseDrive() async {
    final f = await _pick();
    if (f == null) return;
    final settings = ref.read(settingsRepositoryProvider);
    await settings.write(autoBackupDriveUriKey, f.uri);
    await settings.write(
      autoBackupDriveNameKey,
      f.provider.isEmpty ? f.name : '${f.provider} · ${f.name}',
    );
    await settings.write(autoBackupDriveKey, true);
    await _load();
    await _now();
  }

  Future<void> _driveOff() async {
    await ref.read(settingsRepositoryProvider).write(autoBackupDriveKey, false);
    await _load();
  }

  Future<void> _now() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(autoBackupRunnerProvider).run(force: true);
      if (r == null) {
        _say(t('Turn on automatic backup first'));
      } else {
        final n = r.written.values.fold(0, (a, b) => a + b);
        _say(r.ok ? 'Backup done: $n files updated' : 'Backup failed');
      }
    } on Object {
      _say(t('Backup failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Automatic backup'), style: text.titleSmall),
        SwitchListTile(
          key: const Key('auto-backup-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(t('Back up every month automatically')),
          subtitle: Text(t('One file per month, updated after each sync')),
          value: s.on,
          onChanged: _busy ? null : (v) => _toggle(on: v),
        ),
        if (s.on) ...[
          ListTile(
            key: const Key('auto-backup-phone'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_android),
            title: Text(t('On this phone')),
            subtitle: Text(
              s.localName.isEmpty
                  ? t('App storage (removed if the app is uninstalled)')
                  : s.localName,
            ),
            trailing: PopupMenuButton<bool>(
              onSelected: (choose) =>
                  choose ? _chooseLocal() : _useAppStorage(),
              itemBuilder: (_) => [
                PopupMenuItem(value: true, child: Text(t('Choose folder'))),
                if (s.localName.isNotEmpty)
                  PopupMenuItem(
                    value: false,
                    child: Text(t('Use app storage')),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            key: const Key('auto-backup-drive'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.cloud_upload_outlined),
            title: Text(t('Also back up to Google Drive')),
            subtitle: Text(
              s.drive && s.driveName.isNotEmpty
                  ? s.driveName
                  : t('Off. Choose the Drive account and folder to turn on'),
            ),
            value: s.drive,
            onChanged: _busy ? null : (v) => v ? _chooseDrive() : _driveOff(),
          ),
          if (s.drive)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('auto-backup-drive-change'),
                onPressed: _busy ? null : _chooseDrive,
                child: Text(t('Change Drive folder or account')),
              ),
            ),
          Row(
            children: [
              FilledButton(
                key: const Key('auto-backup-now'),
                onPressed: _busy ? null : _now,
                child: Text(t('Back up now')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  key: const Key('auto-backup-last'),
                  s.last == 0
                      ? t('No automatic backup yet')
                      : '${_resultText(s.result)} · '
                          '${AppDates.format(DateTime.fromMillisecondsSinceEpoch(s.last), time: true)}',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ],
    );
  }

  static String _resultText(String r) => switch (r) {
        'ok' => t('Backed up'),
        'phone_failed' => t('Phone copy failed'),
        'cloud_failed' => t('Drive copy failed'),
        _ => t('Checked'),
      };
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog();

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _c.text;
    final ok = p.length >= PassphraseStrength.minLength;
    return AlertDialog(
      title: Text(t('Backup passphrase')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('auto-backup-pass'),
            controller: _c,
            obscureText: true,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t('Passphrase'),
              helperText: p.isEmpty
                  ? t('8 or more characters')
                  : t(PassphraseStrength.of(p).label),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('Needed to restore. It cannot be recovered if you lose it.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          key: const Key('auto-backup-pass-ok'),
          onPressed: ok ? () => Navigator.pop(context, p) : null,
          child: Text(t('Turn on')),
        ),
      ],
    );
  }
}
