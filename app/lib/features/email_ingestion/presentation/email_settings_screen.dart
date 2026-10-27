import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/presentation/email_controller.dart';
import 'package:hisaab/shared/widgets/app_password_guide.dart';

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
  final _code = TextEditingController();
  EmailProvider _provider = EmailProvider.gmail;

  @override
  void dispose() {
    _address.dispose();
    _password.dispose();
    _host.dispose();
    _sender.dispose();
    _code.dispose();
    super.dispose();
  }

  EmailAccount get _form => EmailAccount.forAddress(
        _address.text,
        provider: _provider,
        host: _provider == EmailProvider.custom ? _host.text : null,
      );

  Future<void> _confirmRemove(String address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove $address?'),
        content: const Text('Wipes the saved password. Transactions stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('email-remove-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(emailControllerProvider.notifier).remove(address);
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
          final awaiting = s.codeSentTo != null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final v in s.accounts)
                ListTile(
                  key: Key('email-account-${v.account.address}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline),
                  title: Text(v.account.address),
                  subtitle: Text(
                    v.needsReauth
                        ? 'Sign in again'
                        : (v.account.enabled ? 'Connected' : 'Off'),
                    key: Key('email-status-${v.account.address}'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        key: Key('email-enabled-${v.account.address}'),
                        value: v.account.enabled,
                        onChanged: busy
                            ? null
                            : (on) => c.setEnabled(
                                  v.account.address,
                                  enabled: on,
                                ),
                      ),
                      IconButton(
                        key: Key('email-remove-${v.account.address}'),
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: busy
                            ? null
                            : () => _confirmRemove(v.account.address),
                      ),
                    ],
                  ),
                  onTap: v.needsReauth
                      ? () => setState(() {
                            _address.text = v.account.address;
                            _provider = v.account.provider;
                          })
                      : null,
                ),
              for (final v in s.accounts)
                if (v.lastReport != null)
                  Text(
                    '${v.account.address}: ${v.lastReport}',
                    key: Key('email-last-report-${v.account.address}'),
                    style: text.bodySmall,
                  ),
              if (s.connected) ...[
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('email-sync'),
                  onPressed: busy ? null : c.syncNow,
                  child: Text(s.busy == 'sync' ? 'Syncing...' : 'Sync now'),
                ),
                if (s.busy == 'sync') ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(key: Key('email-progress')),
                ],
              ],
              if (awaiting) ...[
                head('Verify your email'),
                TextField(
                  key: const Key('email-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: '6-digit code'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('email-verify'),
                      onPressed: busy
                          ? null
                          : () async {
                              await c.verify(_code.text);
                              _code.clear();
                              final done = ref
                                      .read(emailControllerProvider)
                                      .value
                                      ?.codeSentTo ==
                                  null;
                              if (done) _address.clear();
                            },
                      child: const Text('Verify'),
                    ),
                    OutlinedButton(
                      key: const Key('email-resend'),
                      onPressed: busy ? null : c.resendCode,
                      child: const Text('Resend code'),
                    ),
                    TextButton(
                      key: const Key('email-cancel-code'),
                      onPressed: busy ? null : c.cancelVerify,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ] else ...[
                head(s.connected ? 'Add another mailbox' : 'Login'),
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
                AppPasswordGuide(_provider),
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
                      key: const Key('email-send-code'),
                      onPressed: busy
                          ? null
                          : () async {
                              await c.sendCode(_form, _password.text);
                              _password.clear();
                            },
                      child: Text(
                        s.busy == 'send' ? 'Sending...' : 'Send code',
                      ),
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
