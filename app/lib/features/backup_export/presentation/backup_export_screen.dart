import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/features/backup_export/presentation/encrypted_backup_section.dart';
import 'package:hisaab/features/backup_export/presentation/reports_section.dart';
import 'package:intl/intl.dart';

/// Backup & Export (F-24): CSV export and import.
class BackupExportScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const BackupExportScreen({super.key});

  @override
  ConsumerState<BackupExportScreen> createState() => _State();
}

class _State extends ConsumerState<BackupExportScreen> {
  bool _busy = false;

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } on FormatException catch (e) {
      _say('Import failed: ${e.message}');
    } on Object catch (e) {
      _say('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // FR-24-02, FR-24-05
  Future<void> _export() => _run(() async {
        final r = await ref.read(backupServiceProvider).export(
              ref.read(backupFileGatewayProvider),
              now: DateTime.now(),
            );
        if (r == null) return;
        ref.invalidate(lastExportProvider);
        _say('Exported ${r.count} transactions to ${r.file}');
      });

  // FR-24-06..13: parse, confirm, then ingest.
  Future<void> _import() => _run(() async {
        final svc = ref.read(backupServiceProvider);
        final text = await ref.read(backupFileGatewayProvider).pickText();
        if (text == null) return;
        final parsed = await svc.parse(text);
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Import transactions?'),
            content: Text(
              '${parsed.rows.length} rows to add'
              '${parsed.badLines > 0 ? ', ${parsed.badLines} unreadable' : ''}.'
              ' Rows already present are skipped.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const Key('backup-import-confirm'),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Import'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final report = await svc.ingest(parsed);
        _say(report.message);
      });

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastExportProvider).value ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const EncryptedBackupSection(),
          const Divider(height: 32),
          const ReportsSection(),
          const Divider(height: 32),
          ListTile(
            key: const Key('backup-export'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file),
            title: const Text('Export CSV'),
            subtitle: const Text('Every transaction, to a file you choose'),
            trailing: FilledButton(
              onPressed: _busy ? null : _export,
              child: const Text('Export'),
            ),
          ),
          ListTile(
            key: const Key('backup-import'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download),
            title: const Text('Import CSV'),
            subtitle: const Text('Rows already present are skipped'),
            trailing: OutlinedButton(
              onPressed: _busy ? null : _import,
              child: const Text('Import'),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            key: const Key('backup-last'),
            last == 0
                ? 'No export yet'
                : 'Last export ${DateFormat('d MMM y, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(last))}',
          ),
          const SizedBox(height: 16),
          const Text(
            'The CSV is plain text, unencrypted. Your data never leaves '
            'this phone.',
          ),
        ],
      ),
    );
  }
}
