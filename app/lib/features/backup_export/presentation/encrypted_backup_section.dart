import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/features/backup_export/domain/backup_errors.dart';
import 'package:hisaab/features/backup_export/domain/full_backup.dart';
import 'package:hisaab/features/backup_export/domain/passphrase_strength.dart';
import 'package:intl/intl.dart';

/// Encrypted full backup and restore (FR-24-17..27): the only way to recover
/// data on a new phone.
class EncryptedBackupSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const EncryptedBackupSection({super.key});

  @override
  ConsumerState<EncryptedBackupSection> createState() => _State();
}

class _State extends ConsumerState<EncryptedBackupSection> {
  bool _busy = false;

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<T?> _run<T>(Future<T> Function() job) async {
    setState(() => _busy = true);
    try {
      return await job();
    } on BackupAuthException {
      _say(BackupAuthException.text);
    } on BackupFormatException catch (e) {
      _say(e.message);
    } on Object catch (e) {
      _say('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  // FR-24-22, FR-24-24
  Future<void> _export() async {
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPassphraseDialog(),
    );
    if (pass == null) return;
    await _run(() async {
      final r = await ref.read(fullBackupServiceProvider).export(
            ref.read(blobGatewayProvider),
            pass,
            now: DateTime.now(),
          );
      if (r == null) return;
      ref.invalidate(lastFullBackupProvider);
      _say('Backup saved to ${r.file}');
    });
  }

  // FR-24-23, FR-24-26, FR-24-27
  Future<void> _restore() async {
    final bytes = await ref.read(blobGatewayProvider).pickBytes();
    if (bytes == null || !mounted) return;
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => const _AskPassphraseDialog(),
    );
    if (pass == null) return;
    final svc = ref.read(fullBackupServiceProvider);
    final opened = await _run(() => svc.open(bytes, pass));
    if (opened == null || !mounted) return;
    final mode = await showDialog<_Mode>(
      context: context,
      builder: (_) => _SummaryDialog(opened),
    );
    if (mode == null || !mounted) return;
    if (mode == _Mode.replace) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (_) => const _ReplaceConfirmDialog(),
      );
      if (sure != true) return;
    }
    final added =
        await _run(() => svc.restore(opened, replace: mode == _Mode.replace));
    if (added == null) return;
    _say(added.total == 0 ? 'Nothing new to add' : 'Restored ${added.text}');
  }

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastFullBackupProvider).value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encrypted backup',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ListTile(
          key: const Key('full-backup-export'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: const Text('Export encrypted backup'),
          subtitle: const Text('Everything, locked with your passphrase'),
          trailing: FilledButton(
            onPressed: _busy ? null : _export,
            child: const Text('Export'),
          ),
        ),
        ListTile(
          key: const Key('full-backup-restore'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.settings_backup_restore),
          title: const Text('Restore from backup'),
          subtitle: const Text('Adds what is missing'),
          trailing: OutlinedButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Restore'),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Text(
          key: const Key('full-backup-last'),
          last == 0
              ? 'No encrypted backup yet'
              : 'Last backup ${DateFormat('d MMM y, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(last))}',
        ),
      ],
    );
  }
}

enum _Mode { merge, replace }

class _NewPassphraseDialog extends StatefulWidget {
  const _NewPassphraseDialog();

  @override
  State<_NewPassphraseDialog> createState() => _NewPassphraseDialogState();
}

class _NewPassphraseDialogState extends State<_NewPassphraseDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = PassphraseStrength.of(_a.text);
    final long = _a.text.length >= PassphraseStrength.minLength;
    final match = _a.text == _b.text;
    return AlertDialog(
      title: const Text('Backup passphrase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('backup-pass'),
              controller: _a,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            if (_a.text.isNotEmpty)
              Text(
                key: const Key('backup-strength'),
                long ? s.label : 'Use at least 8 characters',
              ),
            TextField(
              key: const Key('backup-pass2'),
              controller: _b,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Repeat'),
            ),
            if (_b.text.isNotEmpty && !match) const Text('Passphrases differ'),
            const SizedBox(height: 12),
            const Text(
              'We cannot recover this passphrase. Lose it and the backup '
              'cannot be opened.',
              key: Key('backup-warning'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('backup-pass-ok'),
          onPressed:
              long && match ? () => Navigator.pop(context, _a.text) : null,
          child: const Text('Save backup'),
        ),
      ],
    );
  }
}

class _AskPassphraseDialog extends StatefulWidget {
  const _AskPassphraseDialog();

  @override
  State<_AskPassphraseDialog> createState() => _AskPassphraseDialogState();
}

class _AskPassphraseDialogState extends State<_AskPassphraseDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Backup passphrase'),
        content: TextField(
          key: const Key('restore-pass'),
          controller: _c,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Passphrase'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('restore-pass-ok'),
            onPressed: () => Navigator.pop(context, _c.text),
            child: const Text('Open'),
          ),
        ],
      );
}

class _SummaryDialog extends StatelessWidget {
  const _SummaryDialog(this.opened);

  final OpenedBackup opened;

  @override
  Widget build(BuildContext context) {
    final made = opened.createdAt == 0
        ? ''
        : ' from ${DateFormat('d MMM y').format(DateTime.fromMillisecondsSinceEpoch(opened.createdAt))}';
    return AlertDialog(
      title: const Text('Restore backup?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup$made holds ${opened.counts.text}. '
            'Merge adds what is missing and changes nothing else.',
            key: const Key('restore-summary'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('restore-replace'),
          onPressed: () => Navigator.pop(context, _Mode.replace),
          child: const Text('Replace everything'),
        ),
        TextButton(
          key: const Key('restore-merge'),
          onPressed: () => Navigator.pop(context, _Mode.merge),
          child: const Text('Merge'),
        ),
      ],
    );
  }
}

class _ReplaceConfirmDialog extends StatelessWidget {
  const _ReplaceConfirmDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Erase and replace?'),
        content: const Text(
          'All data on this phone is erased first, then the backup is '
          'restored. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('restore-replace-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erase and restore'),
          ),
        ],
      );
}
