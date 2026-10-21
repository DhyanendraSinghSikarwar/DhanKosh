import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/presentation/holding_labels.dart';

/// Add or edit a holding by hand (FR-16-08). [holding] null adds.
class HoldingSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const HoldingSheet({this.holding, super.key});

  /// Holding being edited.
  final Holding? holding;

  @override
  ConsumerState<HoldingSheet> createState() => _HoldingSheetState();
}

class _HoldingSheetState extends ConsumerState<HoldingSheet> {
  late HoldingKind _kind = widget.holding?.kind ?? HoldingKind.mutualFund;
  late final _name = TextEditingController(text: widget.holding?.name);
  late final _units = TextEditingController(
    text: widget.holding?.units?.toString() ?? '',
  );
  late final _value =
      TextEditingController(text: _rupees(widget.holding?.valueMinor));
  late final _invested =
      TextEditingController(text: _rupees(widget.holding?.investedMinor));

  static String _rupees(int? minor) {
    if (minor == null) return '';
    final p = minor % 100;
    return p == 0
        ? '${minor ~/ 100}'
        : '${minor ~/ 100}.${p.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _name.dispose();
    _units.dispose();
    _value.dispose();
    _invested.dispose();
    super.dispose();
  }

  int? get _valueMinor => parseMoney(_value.text)?.minor;
  int? get _investedMinor =>
      _invested.text.trim().isEmpty ? null : parseMoney(_invested.text)?.minor;
  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_valueMinor ?? -1) >= 0 &&
      (_invested.text.trim().isEmpty || (_investedMinor ?? -1) >= 0);

  Future<void> _save() async {
    final repo = ref.read(holdingRepositoryProvider);
    final units = double.tryParse(_units.text.trim());
    final at = DateTime.now().millisecondsSinceEpoch;
    final h = widget.holding;
    if (h == null) {
      await repo.addManual(
        kind: _kind,
        name: _name.text.trim(),
        valueMinor: _valueMinor!,
        investedMinor: _investedMinor,
        units: units,
        at: at,
      );
    } else {
      await repo.edit(
        h.id,
        kind: _kind,
        name: _name.text.trim(),
        valueMinor: _valueMinor!,
        investedMinor: _investedMinor,
        units: units,
        at: at,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete holding?'),
        content: Text(widget.holding!.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('holding-delete-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    await ref.read(holdingRepositoryProvider).delete(widget.holding!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.holding != null;
    const gap = SizedBox(height: 12);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit holding' : 'Add holding',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            gap,
            DropdownButtonFormField<HoldingKind>(
              key: const Key('holding-kind'),
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final k in HoldingKind.values)
                  DropdownMenuItem(value: k, child: Text(holdingKindLabel(k))),
              ],
              onChanged: (k) => setState(() => _kind = k ?? _kind),
            ),
            gap,
            TextField(
              key: const Key('holding-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            gap,
            TextField(
              key: const Key('holding-units'),
              controller: _units,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Units (optional)'),
            ),
            gap,
            TextField(
              key: const Key('holding-value'),
              controller: _value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Current value',
                prefixText: '₹ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            gap,
            TextField(
              key: const Key('holding-invested'),
              controller: _invested,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Invested (optional)',
                prefixText: '₹ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            gap,
            Row(
              children: [
                if (editing)
                  TextButton(
                    key: const Key('holding-delete'),
                    onPressed: _delete,
                    child: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('holding-save'),
                  onPressed: _valid ? _save : null,
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
