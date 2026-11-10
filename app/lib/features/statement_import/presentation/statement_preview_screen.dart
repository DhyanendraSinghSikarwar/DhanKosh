import 'package:flutter/material.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/statement_import/domain/statement_preview.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart' hide Money;

/// Every statement row with what importing it would do, before anything is
/// written (FR-05-34). Pops the rows the user left unticked; null on cancel.
class StatementPreviewScreen extends StatefulWidget {
  /// Creates the screen.
  const StatementPreviewScreen({required this.preview, super.key});

  /// The plan to show.
  final StatementPreview preview;

  @override
  State<StatementPreviewScreen> createState() => _StatementPreviewScreenState();
}

class _StatementPreviewScreenState extends State<StatementPreviewScreen> {
  late final Set<int> _off = {...widget.preview.skippedByDefault};

  static const _istMs = 19800000;

  static String _day(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms + _istMs, isUtc: true);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _label(PlanKind k) => switch (k) {
        PlanKind.added => t('New'),
        PlanKind.merged => t('Matches existing'),
        PlanKind.review => t('Possible duplicate'),
        PlanKind.skipped => t('Skipped'),
      };

  @override
  Widget build(BuildContext context) {
    final p = widget.preview;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final chosen = p.rows.length - _off.length;
    return Scaffold(
      appBar: AppBar(title: Text(t('Review import'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppCard(
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final k in PlanKind.values)
                    if (p.count(k) > 0)
                      Text(
                        '${_label(k)}: ${p.count(k)}',
                        style: text.bodyMedium,
                      ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: p.rows.length,
              itemBuilder: (_, i) {
                final r = p.rows[i];
                final on = !_off.contains(r.index);
                final debit = r.tx.type == TransactionType.debit;
                return CheckboxListTile(
                  key: Key('preview-row-${r.index}'),
                  value: on,
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _off.remove(r.index);
                    } else {
                      _off.add(r.index);
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    r.tx.merchant ?? t('Statement row'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_day(r.tx.transactionTime)} · ${_label(r.kind)}'
                    '${r.reason == null ? '' : ' · ${r.reason}'}',
                    style: text.bodySmall?.copyWith(
                      color: r.kind == PlanKind.review ? scheme.error : null,
                    ),
                  ),
                  secondary: Text(
                    '${debit ? '-' : '+'}'
                    '${formatMoney(Money(r.tx.amountMinor))}',
                    style: text.bodyMedium?.copyWith(
                      color: debit ? scheme.error : null,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('preview-cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(t('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('preview-confirm'),
                      onPressed: () => Navigator.pop(context, {..._off}),
                      child: Text(
                        t('Import {n}', args: {'n': chosen}),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
