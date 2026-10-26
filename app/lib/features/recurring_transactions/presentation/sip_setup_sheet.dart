import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/sip_providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Add or edit a SIP in steps: frequency, amount, review, confirm
/// (FR-12-19). An existing SIP opens at review and each line is editable in
/// place. Tracking only, no money moves.
class SipSetupSheet extends ConsumerStatefulWidget {
  /// Creates the sheet; [source] edits a SIP (user or detected).
  const SipSetupSheet({this.source, super.key});

  /// SIP to edit or confirm; null adds a new one.
  final Sip? source;

  @override
  ConsumerState<SipSetupSheet> createState() => _SipSetupSheetState();
}

class _SipSetupSheetState extends ConsumerState<SipSetupSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _day;
  late SipFrequency _freq;
  late int _weekday;
  late int _step;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _name = TextEditingController(text: s?.name ?? '');
    final a = s?.amountMinor;
    _amount = TextEditingController(
      text: a == null ? '' : (a % 100 == 0 ? '${a ~/ 100}' : '${a / 100}'),
    );
    _freq = s != null && SipFrequency.manual.contains(s.frequency)
        ? s.frequency
        : SipFrequency.monthly;
    _day = TextEditingController(
      text: '${s?.dayOfMonth ?? s?.nextDate.day ?? 5}',
    );
    _weekday = s?.weekday ?? s?.nextDate.weekday ?? 1;
    _step = s == null ? 0 : 2;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  SipDraft? _draft() {
    final minor = parseMoney(_amount.text)?.minor;
    if (minor == null) return null;
    final today = Ist.dayOf(DateTime.now().millisecondsSinceEpoch);
    return SipDraft(
      name: _name.text.trim(),
      amountMinor: minor,
      frequency: _freq,
      dayOfMonth: int.tryParse(_day.text.trim()),
      weekday: _weekday,
      startDay: widget.source?.startDay ?? today,
    );
  }

  void _go(int step) {
    if (step == 2) {
      final d = _draft();
      final err = d == null ? 'Enter an amount' : d.validate();
      if (err != null) {
        setState(() {
          _error = err;
          _step = 1;
        });
        return;
      }
    }
    setState(() {
      _error = null;
      _step = step;
    });
  }

  Future<void> _save() async {
    final d = _draft();
    if (d == null || d.validate() != null) return _go(1);
    final repo = ref.read(sipRepositoryProvider);
    final id = widget.source?.manualId;
    if (id == null) {
      await repo.add(d);
    } else {
      await repo.update(id, d);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(sipRepositoryProvider).delete(widget.source!.manualId!);
    if (mounted) Navigator.pop(context);
  }

  String get _when => switch (_freq) {
        SipFrequency.monthly => 'Day ${_day.text.trim()} of the month',
        SipFrequency.weekly => 'Every ${_weekdays[_weekday - 1]}',
        _ => 'Every day',
      };

  Widget _body(BuildContext context) {
    switch (_step) {
      case 0:
        return Wrap(
          spacing: 8,
          children: [
            for (final f in SipFrequency.manual)
              ChoiceChip(
                key: Key('sip-freq-${f.name}'),
                label: Text(f.label),
                selected: _freq == f,
                onSelected: (_) => setState(() => _freq = f),
              ),
          ],
        );
      case 1:
        return Column(
          children: [
            TextField(
              key: const Key('sip-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Fund or SIP name'),
            ),
            TextField(
              key: const Key('sip-amount'),
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            if (_freq == SipFrequency.monthly)
              TextField(
                key: const Key('sip-day'),
                controller: _day,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Day of month'),
              ),
            if (_freq == SipFrequency.weekly)
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 1; i <= 7; i++)
                    ChoiceChip(
                      key: Key('sip-wd-$i'),
                      label: Text(_weekdays[i - 1]),
                      selected: _weekday == i,
                      onSelected: (_) => setState(() => _weekday = i),
                    ),
                ],
              ),
          ],
        );
      case 2:
        final d = _draft();
        return Column(
          children: [
            ListTile(
              key: const Key('sip-review-freq'),
              contentPadding: EdgeInsets.zero,
              title: Text(_freq.label),
              subtitle: Text(_when),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _go(0),
            ),
            ListTile(
              key: const Key('sip-review-amount'),
              contentPadding: EdgeInsets.zero,
              title: Text(_name.text.trim().isEmpty ? 'No name' : _name.text),
              subtitle: Text(
                d == null ? '' : formatMoney(Money(d.amountMinor)),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _go(1),
            ),
          ],
        );
      default:
        return const Text(
          'Saved here only. No money moves.',
          key: Key('sip-confirm-note'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Frequency', 'Amount', 'Review', 'Confirm'];
    final editing = widget.source?.manualId != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${editing ? 'Edit SIP' : 'Add SIP'} · ${titles[_step]}',
              key: const Key('sip-step-title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _body(context),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('sip-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (editing && _step == 2)
                  TextButton(
                    key: const Key('sip-delete'),
                    onPressed: _delete,
                    child: const Text('Delete'),
                  ),
                const Spacer(),
                if (_step > 0 && _step != 2)
                  TextButton(
                    key: const Key('sip-back'),
                    onPressed: () => _go(_step - 1),
                    child: const Text('Back'),
                  ),
                if (_step < 3)
                  FilledButton(
                    key: const Key('sip-next'),
                    onPressed: () => _go(_step + 1),
                    child: Text(_step == 2 ? 'Confirm' : 'Next'),
                  )
                else
                  FilledButton(
                    key: const Key('sip-save'),
                    onPressed: _save,
                    child: const Text('Save SIP'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
