import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';
import 'package:hisaab/features/statement_import/presentation/import_result_text.dart';

/// One statement: bank, period, rows imported or merged, account effect,
/// holdings and the holdings-mismatch warning (FR-05-18, FR-05-20).
class StatementDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for statement [id].
  const StatementDetailScreen({required this.id, super.key});

  /// Statement row id.
  final int id;

  @override
  ConsumerState<StatementDetailScreen> createState() => _State();
}

class _State extends ConsumerState<StatementDetailScreen> {
  bool _busy = false;

  Future<void> _again() async {
    setState(() => _busy = true);
    final r = await ref.read(importStatementProvider).readAgain(widget.id);
    ref.invalidate(statementDetailProvider(widget.id));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(importResultText(r))));
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _day(int epochDay) {
    final d = DateTime.utc(1970).add(Duration(days: epochDay));
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  static String _m(int? minor) =>
      minor == null ? '-' : formatMoney(Money(minor));

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(statementDetailProvider(widget.id));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Statement')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Cannot load statement.')),
        data: (d) {
          if (d == null) return const Center(child: Text('Not found.'));
          final s = d.statement;
          final o = d.outcome;
          final t = s.totals;
          final rows = <(String, String)>[
            ('File', s.fileName),
            if (s.bankName != null)
              (
                'Bank',
                s.last4 == null ? s.bankName! : '${s.bankName} ${s.last4}',
              ),
            if (t.statementEpochDay != null)
              ('Statement date', _day(t.statementEpochDay!)),
            ('Status', s.status.name),
            ('Rows imported', '${o?.added ?? s.transactionCount}'),
            if (o != null) ('Rows merged', '${o.merged}'),
            if (o != null && o.review > 0) ('To review', '${o.review}'),
            ('Holdings updated', '${o?.holdingsUpdated ?? s.holdingCount}'),
            if (o != null && o.depositsUpdated > 0)
              ('Deposits updated', '${o.depositsUpdated}'),
            if (t.totalDueMinor != null) ('Total due', _m(t.totalDueMinor)),
            if (t.minDueMinor != null) ('Minimum due', _m(t.minDueMinor)),
            if (t.dueEpochDay != null) ('Due date', _day(t.dueEpochDay!)),
            if (t.creditLimitMinor != null)
              ('Credit limit', _m(t.creditLimitMinor)),
            if (t.openingMinor != null) ('Opening', _m(t.openingMinor)),
            if (t.closingMinor != null) ('Closing', _m(t.closingMinor)),
          ];
          final e = o?.effect;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (o?.mismatch != null)
                Container(
                  key: const Key('statement-mismatch'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  color: scheme.errorContainer,
                  child: Text(
                    'Holdings differ from the statement total: '
                    '${_m(o!.mismatch!.rowsValueMinor)} read, '
                    '${_m(o.mismatch!.statedValueMinor)} stated.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              for (final (k, v) in rows)
                ListTile(
                  dense: true,
                  title: Text(k),
                  trailing: Text(v),
                ),
              if (e != null && e.applied)
                ListTile(
                  key: const Key('statement-effect'),
                  dense: true,
                  title: Text(
                    e.kind == AccountEffectKind.availableLimit
                        ? 'Available limit applied'
                        : 'Balance applied',
                  ),
                  trailing: Text(_m(e.amountMinor)),
                ),
              if (s.filePath != null && s.status != StatementStatus.locked)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    key: const Key('statement-read-again'),
                    onPressed: _busy ? null : _again,
                    child: const Text('Read again'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
