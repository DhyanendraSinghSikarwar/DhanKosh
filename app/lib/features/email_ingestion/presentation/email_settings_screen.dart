import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/presentation/email_controller.dart';

/// Email sources: mailbox login, senders, sync (F-03, FR-03-22).
class EmailSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() => _State();
}

class _State extends ConsumerState<EmailSettingsScreen> {
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _host = TextEditingController();
  final _sender = TextEditingController();
  EmailProvider _provider = EmailProvider.gmail;

  @override
  void dispose() {
    _address.dispose();
    _password.dispose();
    _host.dispose();
    _sender.dispose();
    super.dispose();
  }

  EmailAccount get _form => EmailAccount.forAddress(
        _address.text,
        provider: _provider,
        host: _provider == EmailProvider.custom ? _host.text : null,
      );

  Future<void> _confirmDisconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Disconnect email?'),
        content: const Text('Wipes the saved password. Transactions stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('email-disconnect-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(emailControllerProvider.notifier).disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(emailControllerProvider);
    final c = ref.read(emailControllerProvider.notifier);
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: text.titleSmall),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Email')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load email.')),
        data: (s) {
          final busy = s.busy != null;
          final showForm = !s.connected || s.needsReauth;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.connected) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline),
                  title: Text(s.account!.address),
                  subtitle: Text(
                    s.needsReauth ? 'Sign in again' : 'Connected',
                    key: const Key('email-status'),
                  ),
                ),
                if (s.lastReport != null)
                  Text(
                    s.lastReport!,
                    key: const Key('email-last-report'),
                    style: text.bodySmall,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('email-sync'),
                      onPressed: busy || s.needsReauth ? null : c.syncNow,
                      child: Text(s.busy == 'sync' ? 'Syncing...' : 'Sync now'),
                    ),
                    OutlinedButton(
                      key: const Key('email-disconnect'),
                      onPressed: busy ? null : _confirmDisconnect,
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
                if (s.busy == 'sync') ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(key: Key('email-progress')),
                ],
              ],
              if (showForm) ...[
                head('Login'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in EmailProvider.values)
                      ChoiceChip(
                        key: Key('email-provider-${p.name}'),
                        label: Text(p.label),
                        selected: _provider == p,
                        onSelected: (_) => setState(() => _provider = p),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('email-address'),
                  controller: _address,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  onChanged: (v) {
                    final d = EmailProvider.detect(v);
                    if (d != EmailProvider.custom && d != _provider) {
                      setState(() => _provider = d);
                    }
                  },
                ),
                if (_provider == EmailProvider.custom)
                  TextField(
                    key: const Key('email-host'),
                    controller: _host,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'IMAP server'),
                  ),
                TextField(
                  key: const Key('email-password'),
                  controller: _password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'App password'),
                ),
                const SizedBox(height: 8),
                Text(
                  'An app password is separate from your normal one.',
                  style: text.bodySmall,
                ),
                for (var i = 0; i < _provider.steps.length; i++)
                  Text(
                    '${i + 1}. ${_provider.steps[i]}',
                    style: text.bodySmall,
                  ),
                if (_provider.appPasswordUrl != null)
                  SelectableText(
                    _provider.appPasswordUrl!,
                    style: text.bodySmall,
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('email-test'),
                      onPressed:
                          busy ? null : () => c.test(_form, _password.text),
                      child: Text(
                        s.busy == 'test' ? 'Testing...' : 'Test connection',
                      ),
                    ),
                    FilledButton(
                      key: const Key('email-save'),
                      onPressed: busy
                          ? null
                          : () async {
                              await c.save(_form, _password.text);
                              _password.clear();
                            },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
              if (s.message != null) ...[
                const SizedBox(height: 12),
                Text(s.message!, key: const Key('email-message')),
              ],
              head('Bank senders'),
              Text(
                '${s.defaultSenderCount} default senders'
                '${s.customSenders.isEmpty ? '' : ' + ${s.customSenders.length} yours'}. '
                'Statement subjects are always read.',
                style: text.bodySmall,
              ),
              for (final x in s.customSenders.toList()..sort())
                ListTile(
                  key: Key('email-sender-$x'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(x),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => c.removeSender(x),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('email-sender-input'),
                      controller: _sender,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Add address or domain',
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('email-sender-add'),
                    tooltip: 'Add',
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      await c.addSender(_sender.text);
                      _sender.clear();
                    },
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('email-sender-reset'),
                  onPressed: s.customSenders.isEmpty ? null : c.resetSenders,
                  child: const Text('Reset to defaults'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
