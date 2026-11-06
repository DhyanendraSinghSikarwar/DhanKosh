import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/share_in_providers.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/presentation/import_result_text.dart';
import 'package:hisaab/features/statement_import/presentation/statement_mail_sheet.dart';
import 'package:hisaab/features/statement_import/presentation/unlock_statement_sheet.dart';

/// Imported statements: list with status, locked banner, import and delete
/// (FR-05-01, FR-05-11, FR-05-19).
class StatementsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const StatementsScreen({super.key, this.unlockId});

  /// Locked statement to open the password sheet for, once (FR-05-19).
  final int? unlockId;

  @override
  ConsumerState<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends ConsumerState<StatementsScreen> {
  bool _busy = false;
  bool _deepLinked = false;

  void _say(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _import() async {
    final file = await ref.read(statementFileSourceProvider).pick();
    await _importFile(file);
  }

  /// A file shared from another app, imported like a picked one (FR-05-26).
  void _takeShared() {
    final f = ref.read(sharedInboxProvider.notifier).take();
    if (f != null) unawaited(_importFile(f));
  }

  Future<void> _importFile(PickedFile? file) async {
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    ImportResult r;
    try {
      r = await ref.read(importStatementProvider).call(file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    _say(importResultText(r));
    if (r is ImportLocked) await _unlock(r.statementId, file.name);
  }

  Future<void> _unlock(int id, String name, [Statement? known]) async {
    // The row may not be in the list yet when it was just imported.
    final st = known ?? await ref.read(statementRepositoryProvider).byId(id);
    if (!mounted) return;
    final r = await showModalBottomSheet<ImportResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UnlockStatementSheet(
        statementId: id,
        fileName: name,
        statement: st,
      ),
    );
    if (r != null && mounted) _say(importResultText(r));
  }

  void _open(Statement s) => unawaited(context.push('/statements/${s.id}'));

  Future<void> _delete(Statement s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete statement?'),
        content: const Text('Imported transactions stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('statement-delete-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(importStatementProvider).delete(s.id);
  }

  static String _subtitle(Statement s) {
    final base = _status(s);
    final subject = s.subject?.trim();
    return s.source == StatementSource.email &&
            subject != null &&
            subject.isNotEmpty
        ? '$subject\n$base'
        : base;
  }

  static String _status(Statement s) => switch (s.status) {
        StatementStatus.locked => 'Locked',
        StatementStatus.unreadable => 'Unreadable',
        StatementStatus.empty => 'Nothing found',
        StatementStatus.parsed => [
            if (s.bankName != null) s.bankName!,
            if (s.transactionCount > 0) '${s.transactionCount} rows',
            if (s.holdingCount > 0) '${s.holdingCount} holdings',
          ].join(' · '),
      };

  @override
  void initState() {
    super.initState();
    ref.listenManual<PickedFile?>(
      sharedInboxProvider,
      (_, next) {
        if (next == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _takeShared();
        });
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(statementsProvider).value ?? const <Statement>[];
    final locked = ref.watch(lockedStatementCountProvider).value ?? 0;
    final scheme = Theme.of(context).colorScheme;
    final link = widget.unlockId;
    if (link != null && !_deepLinked) {
      for (final s in list) {
        if (s.id == link && s.isLocked) {
          _deepLinked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_unlock(s.id, s.fileName, s));
          });
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statements'),
        actions: [
          IconButton(
            key: const Key('statements-import'),
            tooltip: 'Import',
            icon: const Icon(Icons.upload_file),
            onPressed: _busy ? null : _import,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (locked > 0)
            Container(
              key: const Key('statements-locked-banner'),
              width: double.infinity,
              color: scheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                '$locked locked',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No statements yet.'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return ListTile(
                        key: Key('statement-${s.id}'),
                        leading: Icon(
                          s.isLocked ? Icons.lock_outline : Icons.description,
                          color: s.isLocked ? scheme.error : null,
                        ),
                        title: Text(s.fileName, maxLines: 1),
                        subtitle: Text(
                          _subtitle(s),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: _subtitle(s).contains('\n'),
                        onTap: s.isLocked
                            ? () => _unlock(s.id, s.fileName, s)
                            : () => _open(s),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasMail(s))
                              IconButton(
                                key: Key('statement-mail-${s.id}'),
                                tooltip: 'View email',
                                icon: const Icon(Icons.mail_outline),
                                onPressed: () => showStatementMail(context, s),
                              ),
                            IconButton(
                              key: Key('statement-delete-${s.id}'),
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(s),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
