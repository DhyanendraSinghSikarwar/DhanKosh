import 'package:flutter/material.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';

/// Result of Edit amounts: values to store (equal-to-calculated are dropped
/// by `CardDueActions.saveEdit`) or a reset of all overrides.
class CardEditResult {
  /// Creates a result.
  const CardEditResult({
    this.reset = false,
    this.billed,
    this.minDue,
    this.unbilled,
    this.outstanding,
    this.dueDay,
  });

  /// Reset all overrides.
  final bool reset;

  /// Billed, paise.
  final int? billed;

  /// Minimum due, paise.
  final int? minDue;

  /// Unbilled, paise.
  final int? unbilled;

  /// Total outstanding, paise.
  final int? outstanding;

  /// Due date, IST epoch day.
  final int? dueDay;
}

/// Edit amounts with Calculated hints and per-field reset (FR-14-07).
class CardAmountsSheet extends StatefulWidget {
  /// Creates the sheet.
  const CardAmountsSheet({required this.card, super.key});

  /// Card being edited.
  final CardLimit card;

  @override
  State<CardAmountsSheet> createState() => _CardAmountsSheetState();
}

class _CardAmountsSheetState extends State<CardAmountsSheet> {
  late final CardPosition _calc =
      widget.card.position.calculated ?? widget.card.position;
  late final Map<String, TextEditingController> _c;
  late int? _due = widget.card.dueDay;

  static const _fields = ['billed', 'minDue', 'unbilled', 'outstanding'];

  int? _calcOf(String f) => switch (f) {
        'billed' => _calc.billedMinor,
        'minDue' => _calc.minDueMinor,
        'unbilled' => _calc.unbilledMinor,
        _ => _calc.outstandingMinor,
      };

  int? _curOf(String f) => switch (f) {
        'billed' => widget.card.billedMinor,
        'minDue' => widget.card.minDueMinor,
        'unbilled' => widget.card.unbilledMinor,
        _ => widget.card.outstandingMinor,
      };

  static String _text(int? minor) => minor == null
      ? ''
      : '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _c = {
      for (final f in _fields)
        f: TextEditingController(text: _text(_curOf(f)))
          ..addListener(() => setState(() {})),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Null when empty; -1 when invalid.
  int? _value(String f) {
    final t = _c[f]!.text.trim();
    if (t.isEmpty) return null;
    final m = parseMoney(t);
    return m == null || m.minor < 0 ? -1 : m.minor;
  }

  bool get _valid => _fields.every((f) => _value(f) != -1);

  bool get _changed =>
      _due != widget.card.dueDay || _fields.any((f) => _value(f) != _curOf(f));

  static const _labels = {
    'billed': 'Billed',
    'minDue': 'Min due',
    'unbilled': 'Unbilled',
    'outstanding': 'Total outstanding',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit amounts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final f in _fields) ...[
              TextField(
                key: Key('card_field_$f'),
                controller: _c[f],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _labels[f],
                  prefixText: '₹ ',
                  errorText: _value(f) == -1 ? 'Enter an amount' : null,
                  helperText: _calcOf(f) == null
                      ? null
                      : 'Calculated ${formatMoney(Money(_calcOf(f)!))}',
                  suffixIcon: _value(f) != _calcOf(f)
                      ? IconButton(
                          key: Key('card_reset_$f'),
                          tooltip: 'Reset',
                          icon: const Icon(Icons.restart_alt),
                          onPressed: () => _c[f]!.text = _text(_calcOf(f)),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ListTile(
              key: const Key('card_field_due'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Due date'),
              subtitle: Text(
                _due == null ? 'Not set' : cardDate(_due!),
              ),
              trailing: _due != _calc.dueDay
                  ? IconButton(
                      key: const Key('card_reset_due'),
                      tooltip: 'Reset',
                      icon: const Icon(Icons.restart_alt),
                      onPressed: () => setState(() => _due = _calc.dueDay),
                    )
                  : null,
              onTap: () async {
                final today = DateTime.now();
                final init = _due == null
                    ? today
                    : DateTime.utc(1970).add(Duration(days: _due!));
                final d = await showDatePicker(
                  context: context,
                  initialDate: init,
                  firstDate: DateTime(today.year - 1),
                  lastDate: DateTime(today.year + 2),
                );
                if (d != null) {
                  setState(
                    () => _due = CardDay.fromYmd(d.year, d.month, d.day),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.card.position.edited)
                  TextButton(
                    key: const Key('card_reset_all'),
                    onPressed: () => Navigator.pop(
                      context,
                      const CardEditResult(reset: true),
                    ),
                    child: const Text('Reset all'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('card_save'),
                  onPressed: _valid && _changed
                      ? () => Navigator.pop(
                            context,
                            CardEditResult(
                              billed: _value('billed'),
                              minDue: _value('minDue'),
                              unbilled: _value('unbilled'),
                              outstanding: _value('outstanding'),
                              dueDay: _due,
                            ),
                          )
                      : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
