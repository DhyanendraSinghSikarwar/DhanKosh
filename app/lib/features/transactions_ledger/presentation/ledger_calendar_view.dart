import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_tx_tile.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Month grid with a per-day value for the filter's kind; tapping a day lists
/// its rows (FR-08-03, FR-08-21). Honours the filter's period: months outside
/// [rangeStart]..[rangeEnd] (or the rows' own span) cannot be opened.
class LedgerCalendarView extends StatefulWidget {
  /// Creates the view over [rows] (already filtered by period, kind, query).
  const LedgerCalendarView({
    required this.rows,
    required this.kind,
    required this.masked,
    required this.rowBuilder,
    this.rangeStart,
    this.rangeEnd,
    super.key,
  });

  /// Rows to plot.
  final List<LedgerTx> rows;

  /// Selected kind (drives caption and values).
  final TxKind kind;

  /// Hide-amounts setting.
  final bool masked;

  /// Builds a tile for one row.
  final Widget Function(LedgerTx) rowBuilder;

  /// Inclusive period start / exclusive end; null uses the rows' span.
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  @override
  State<LedgerCalendarView> createState() => _State();
}

class _State extends State<LedgerCalendarView> {
  DateTime? _month;
  DateTime? _day;

  DateTime _first() {
    if (widget.rangeStart != null) return widget.rangeStart!;
    if (widget.rows.isEmpty) return DateTime.now();
    final m =
        widget.rows.map((r) => r.timestamp).reduce((a, b) => a < b ? a : b);
    return DateTime.fromMillisecondsSinceEpoch(m);
  }

  DateTime _last() {
    if (widget.rangeEnd != null) {
      return widget.rangeEnd!.subtract(const Duration(milliseconds: 1));
    }
    if (widget.rows.isEmpty) return DateTime.now();
    final m =
        widget.rows.map((r) => r.timestamp).reduce((a, b) => a > b ? a : b);
    return DateTime.fromMillisecondsSinceEpoch(m);
  }

  DateTime _clamp(DateTime m) {
    final lo = DateTime(_first().year, _first().month);
    final hi = DateTime(_last().year, _last().month);
    if (m.isBefore(lo)) return lo;
    if (m.isAfter(hi)) return hi;
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    final lo = DateTime(_first().year, _first().month);
    final hi = DateTime(_last().year, _last().month);
    final month = _clamp(
      _month ?? (widget.rangeStart != null ? _first() : _last()),
    );
    final m = DateTime(month.year, month.month);
    final values = dayValues(widget.rows, widget.kind);
    final color = widget.kind == TxKind.income ? sem.income : AppIcons.mint;
    final peak = values.values.fold<int>(0, (a, b) => a > b ? a : b);
    final days = DateTime(m.year, m.month + 1, 0).day;
    final lead = DateTime(m.year, m.month).weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        _cell(theme, color, DateTime(m.year, m.month, d), values, peak),
    ];
    final selected = _day;
    final monthTotal = values.entries
        .where((e) => e.key.year == m.year && e.key.month == m.month)
        .fold<int>(0, (a, e) => a + e.value);
    final dayRows = selected == null
        ? const <LedgerTx>[]
        : [
            for (final t in widget.rows)
              if (_sameDay(
                DateTime.fromMillisecondsSinceEpoch(t.timestamp),
                selected,
              ))
                t,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('cal_prev'),
                    tooltip: 'Previous month',
                    onPressed: m.isAfter(lo)
                        ? () => setState(
                              () => _month = DateTime(m.year, m.month - 1),
                            )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[m.month - 1]} ${m.year}',
                      key: const Key('cal_title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('cal_next'),
                    tooltip: 'Next month',
                    onPressed: m.isBefore(hi)
                        ? () => setState(
                              () => _month = DateTime(m.year, m.month + 1),
                            )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              SectionLabel(
                calendarCaption(widget.kind),
                key: const Key('cal_caption'),
              ),
              const SizedBox(height: 4),
              Text(
                formatMoney(
                  Money(monthTotal),
                  masked: widget.masked,
                  showPaise: false,
                ),
                key: const Key('cal_month_total'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(w, style: theme.textTheme.labelSmall),
                      ),
                    ),
                ],
              ),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.9,
                children: cells,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${selected.day} ${_months[selected.month - 1]}',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  formatMoney(
                    Money(values[selected] ?? 0),
                    masked: widget.masked,
                    showPaise: false,
                  ),
                  key: const Key('cal_day_total'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        if (selected != null)
          AppCard(
            key: const Key('cal_day_rows'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: dayRows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No transactions on this day'),
                  )
                : Column(
                    children: withDividers(
                      [for (final t in dayRows) widget.rowBuilder(t)],
                    ),
                  ),
          ),
      ],
    );
  }

  /// Whole-rupee amount in K / L for a day cell.
  String _compact(int minor) {
    final r = minor / 100;
    if (r >= 100000) return '${(r / 100000).toStringAsFixed(1)}L';
    if (r >= 1000) return '${(r / 1000).toStringAsFixed(r >= 10000 ? 0 : 1)}K';
    return r.round().toString();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _cell(
    ThemeData theme,
    Color color,
    DateTime day,
    Map<DateTime, int> values,
    int peak,
  ) {
    final v = values[day];
    final sel = _day != null && _sameDay(_day!, day);
    final heat = v == null || peak == 0 ? 0.0 : 0.1 + 0.5 * (v / peak);
    final base = theme.colorScheme.surfaceContainerHighest;
    return InkWell(
      key: Key('cal_day_${day.day}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _day = day),
      child: Container(
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: heat), base),
          borderRadius: BorderRadius.circular(8),
          border: sel ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              key: v == null ? null : Key('cal_val_${day.day}'),
              style: const TextStyle(fontSize: 11),
            ),
            if (v != null)
              Text(
                widget.masked ? '••' : _compact(v),
                style: TextStyle(
                  fontSize: 8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
