import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';

const _defaultCurrencies = ['USD', 'EUR', 'GBP', 'AED', 'SGD'];

String _dayLabel(int day) {
  final d = fromEpochDay(day);
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Manual forex rates and the foreign spends that need one (FR-23-02,
/// FR-23-03, FR-23-13).
class ForexRatesScreen extends ConsumerWidget {
  /// Creates the screen.
  const ForexRatesScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    String? currency,
    ForexRate? existing,
  }) async {
    final foreign = ref.read(forexForeignProvider).value ?? const [];
    final draft = await showDialog<RateDraft>(
      context: context,
      builder: (_) => _RateDialog(
        currencies: {
          for (final c in foreign) c.currency,
          ..._defaultCurrencies,
        }.toList(),
        initial: existing == null
            ? RateDraft(currency: currency ?? 'USD', day: DateTime.now())
            : RateDraft(
                currency: existing.currency,
                day: fromEpochDay(existing.day),
                rateText: '${existing.inrPerUnit}',
              ),
      ),
    );
    if (draft == null || !draft.canSave) return;
    await ref.read(forexRepositoryProvider).upsert(
          ForexRate(
            currency: draft.currency.toUpperCase(),
            day: epochDayOf(
              DateTime.utc(draft.day.year, draft.day.month, draft.day.day),
            ),
            inrPerUnit: draft.rate!,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final rates = ref.watch(forexRatesProvider).value ?? const <ForexRate>[];
    final foreign = ref.watch(forexForeignProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Forex rates')),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        key: const Key('forex-add'),
        onPressed: () => unawaited(_edit(context, ref)),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Card(
            key: const Key('forex-abroad'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your spends abroad', style: text.titleSmall),
                  const SizedBox(height: 8),
                  if (foreign.isEmpty)
                    const Text('No foreign spends', key: Key('forex-none')),
                  for (final c in foreign)
                    Row(
                      children: [
                        Expanded(
                          child: Text('${c.currency}: ${c.count}'),
                        ),
                        if (c.unpriced > 0)
                          TextButton(
                            key: Key('forex-need-${c.currency}'),
                            onPressed: () => unawaited(
                              _edit(context, ref, currency: c.currency),
                            ),
                            child: Text('${c.unpriced} need a rate'),
                          )
                        else
                          Text(
                            'All counted',
                            key: Key('forex-ok-${c.currency}'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Spends without a rate are left out of totals.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          if (rates.isEmpty)
            const Text('No rates yet', key: Key('forex-empty')),
          for (final r in rates)
            ListTile(
              key: Key('forex-rate-${r.currency}-${r.day}'),
              contentPadding: EdgeInsets.zero,
              title: Text('${r.currency}  ${r.inrPerUnit}'),
              subtitle: Text(_dayLabel(r.day)),
              onTap: () => unawaited(_edit(context, ref, existing: r)),
              trailing: IconButton(
                key: Key('forex-del-${r.currency}-${r.day}'),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => unawaited(
                  ref.read(forexRepositoryProvider).delete(r.currency, r.day),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.currencies, required this.initial});

  final List<String> currencies;
  final RateDraft initial;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final TextEditingController _code =
      TextEditingController(text: widget.initial.currency);
  late final TextEditingController _rate =
      TextEditingController(text: widget.initial.rateText);
  late DateTime _day = widget.initial.day;

  @override
  void dispose() {
    _code.dispose();
    _rate.dispose();
    super.dispose();
  }

  RateDraft get _draft =>
      RateDraft(currency: _code.text, day: _day, rateText: _rate.text);

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _day = d);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exchange rate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final c in widget.currencies)
                  ChoiceChip(
                    key: Key('forex-chip-$c'),
                    label: Text(c),
                    selected: _code.text.toUpperCase() == c,
                    onSelected: (_) => setState(() => _code.text = c),
                  ),
              ],
            ),
            TextField(
              key: const Key('forex-code'),
              controller: _code,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
              ],
              decoration: const InputDecoration(labelText: 'Currency'),
              onChanged: (_) => setState(() {}),
            ),
            TextButton.icon(
              key: const Key('forex-date'),
              onPressed: _pick,
              icon: const Icon(Icons.event),
              label: Text(
                '${_day.day}/${_day.month}/${_day.year}',
              ),
            ),
            TextField(
              key: const Key('forex-rate'),
              controller: _rate,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
              ],
              decoration: const InputDecoration(labelText: 'Rupees per unit'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('forex-save'),
          onPressed:
              _draft.canSave ? () => Navigator.pop(context, _draft) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
