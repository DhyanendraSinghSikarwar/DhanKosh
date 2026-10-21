import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';

/// Asks for a statement's password once (FR-05-12). Pops the
/// [ImportResult] when the statement opened, else stays with an error.
class UnlockStatementSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for LOCKED statement [statementId].
  const UnlockStatementSheet({
    required this.statementId,
    required this.fileName,
    super.key,
  });

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
          Text('Unlock statement', style: text.titleMedium),
          Text(widget.fileName, style: text.bodySmall),
          const SizedBox(height: 12),
          TextField(
            key: const Key('unlock-password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          CheckboxListTile(
            key: const Key('unlock-remember'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Save for this bank'),
            subtitle: const Text('Encrypted on this phone'),
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
