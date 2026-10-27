import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/settings_data_sources/presentation/sender_lists_controller.dart';

/// Editable bank sender list (SMS ids) and mail-domain list (FR-26-31).
class SenderListsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SenderListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(senderListsControllerProvider);
    final c = ref.read(senderListsControllerProvider.notifier);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bank senders'),
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('senders-tab-sms'), text: 'SMS'),
              Tab(key: Key('senders-tab-mail'), text: 'Mail'),
            ],
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Could not load senders.')),
          data: (s) => TabBarView(
            children: [
              _ListTab(
                prefix: 'sms',
                hint: 'Add sender id, e.g. HDFCBK',
                defaults: s.smsDefaults,
                added: s.sms.added,
                off: s.sms.removed,
                onAdd: c.addSms,
                onRemoveAdded: c.removeAddedSms,
                onToggle: c.setSmsDefault,
                onReset: c.resetSms,
              ),
              _ListTab(
                prefix: 'mail',
                hint: 'Add address or domain',
                defaults: s.mailDefaults,
                added: s.mailAdded,
                off: s.mailRemoved,
                onAdd: c.addMail,
                onRemoveAdded: c.removeAddedMail,
                onToggle: c.setMailDefault,
                onReset: c.resetMail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListTab extends StatefulWidget {
  const _ListTab({
    required this.prefix,
    required this.hint,
    required this.defaults,
    required this.added,
    required this.off,
    required this.onAdd,
    required this.onRemoveAdded,
    required this.onToggle,
    required this.onReset,
  });

  final String prefix;
  final String hint;
  final List<String> defaults;
  final Set<String> added;
  final Set<String> off;
  final Future<bool> Function(String) onAdd;
  final Future<void> Function(String) onRemoveAdded;
  final Future<void> Function(String, {required bool on}) onToggle;
  final Future<void> Function() onReset;

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final ok = await widget.onAdd(_input.text);
    if (!mounted) return;
    setState(() => _error = ok ? null : 'Not a valid entry.');
    if (ok) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prefix;
    final mine = widget.added.toList()..sort();
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('senders-$p-input'),
                  controller: _input,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: widget.hint,
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(
                key: Key('senders-$p-add'),
                tooltip: 'Add',
                icon: const Icon(Icons.add),
                onPressed: _add,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.defaults.length - widget.off.length} default on, '
                  '${mine.length} yours',
                  key: Key('senders-$p-count'),
                  style: text.bodySmall,
                ),
              ),
              TextButton(
                key: Key('senders-$p-reset'),
                onPressed: widget.added.isEmpty && widget.off.isEmpty
                    ? null
                    : widget.onReset,
                child: const Text('Reset to defaults'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: mine.length + widget.defaults.length,
            itemBuilder: (context, i) {
              if (i < mine.length) {
                final k = mine[i];
                return ListTile(
                  key: Key('senders-$p-added-$k'),
                  dense: true,
                  title: Text(k),
                  subtitle: const Text('Yours'),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.onRemoveAdded(k),
                  ),
                );
              }
              final k = widget.defaults[i - mine.length];
              return SwitchListTile(
                key: Key('senders-$p-default-$k'),
                dense: true,
                title: Text(k),
                value: !widget.off.contains(k),
                onChanged: (on) => widget.onToggle(k, on: on),
              );
            },
          ),
        ),
      ],
    );
  }
}
