import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/presentation/statement_mail_sheet.dart';

/// Asks for a statement's password once (FR-05-12). Pops the
/// [ImportResult] when the statement opened, else stays with an error.
class UnlockStatementSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for LOCKED statement [statementId].
  const UnlockStatementSheet({
    required this.statementId,
    required this.fileName,
    this.statement,
    super.key,
  });

  /// The stored statement, when known: its email subject says what kind of
  /// statement is asking for a password (FR-05-30).
  final Statement? statement;

  /// Row to unlock.
  final int statementId;

  /// Shown as the subtitle.
  final String fileName;

  @override
  ConsumerState<UnlockStatementSheet> createState() => _State();
}

class _State extends ConsumerState<UnlockStatementSheet> {
  final _password = TextEditingController();
  bool _remember = false;
  bool _busy = false;
  String? _error;

  String? get _subject {
    final st = widget.statement;
    final t = st?.subject?.trim();
    return st != null && st.source == StatementSource.email && t != null
        ? (t.isEmpty ? null : t)
        : null;
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(importStatementProvider).unlock(
          widget.statementId,
          _password.text,
          remember: _remember,
        );
    if (!mounted) return;
    if (r is ImportWrongPassword) {
      setState(() {
        _busy = false;
        _error = 'Wrong password.';
      });
    } else {
      Navigator.of(context).pop(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Unlock statement'), style: text.titleMedium),
          if (_subject case final subject?) ...[
            Text(
              subject,
              key: const Key('unlock-subject'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall,
            ),
            Text(
              '${widget.fileName} · from ${widget.statement!.sender}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ] else
            Text(widget.fileName, style: text.bodySmall),
          if (widget.statement case final st? when hasMail(st))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('unlock-view-mail'),
                onPressed: () => showStatementMail(context, st),
                icon: const Icon(Icons.mail_outline, size: 18),
                label: Text(t('View email')),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('unlock-password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: t('Password'),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          CheckboxListTile(
            key: const Key('unlock-remember'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t('Save for this bank')),
            subtitle: Text(t('Encrypted on this phone')),
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('unlock-submit'),
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Unlocking' : 'Unlock'),
            ),
          ),
        ],
      ),
    );
  }
}
