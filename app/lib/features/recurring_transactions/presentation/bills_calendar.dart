import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:parser_core/parser_core.dart';

const _names = [
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

/// Month grid with a dot per mark and per-day selection (FR-12-09, 10).
class BillsCalendar extends StatelessWidget {
  /// Creates the calendar.
  const BillsCalendar({
    required this.items,
    required this.month,
    required this.selected,
    required this.onMonth,
    required this.onSelect,
    super.key,
  });

  /// Everything shown on the calendar.
  final List<Recurring> items;

  /// First day of the shown month (UTC).
  final DateTime month;

  /// Selected day, if any.
  final DateTime? selected;

  /// Month changed by a delta of -1 or 1.
  final ValueChanged<int> onMonth;

  /// A day tapped.
  final ValueChanged<DateTime> onSelect;

  /// Dot colour of [r].
  static Color markColor(BuildContext context, Recurring r) {
    final c = Theme.of(context).extension<SemanticColors>();
    final scheme = Theme.of(context).colorScheme;
    if (r.income) return c?.income ?? Colors.green;
    if (r.loanKey != null) return scheme.primary;
    if (r.category == Category.insurance) return c?.warning ?? Colors.orange;
    return c?.expense ?? Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final len = DateTime.utc(month.year, month.month + 1, 0).day;
    final lead = month.weekday % 7; // Sunday first
    final cells = <Widget>[
      for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
        Center(child: Text(d, style: text.labelSmall)),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= len; d++)
        _day(context, DateTime.utc(month.year, month.month, d)),
    ];
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('cal-prev'),
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMonth(-1),
            ),
            Expanded(
              child: Text(
                '${_names[month.month - 1]} ${month.year}',
                key: const Key('cal-title'),
                textAlign: TextAlign.center,
                style: text.titleSmall,
              ),
            ),
            IconButton(
              key: const Key('cal-next'),
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onMonth(1),
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          children: cells,
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 12,
          children: [
            _Legend('Payment', Icons.circle),
            _Legend('EMI', Icons.circle, emi: true),
            _Legend('Income', Icons.circle, income: true),
            _Legend('Insurance', Icons.circle, insurance: true),
          ],
        ),
      ],
    );
  }

  Widget _day(BuildContext context, DateTime date) {
    final on = [
      for (final r in items)
        if (RecurringDetector.occursOn(r, date)) r,
    ];
    final scheme = Theme.of(context).colorScheme;
    final sel = selected == date;
    return InkWell(
      key: Key('cal-day-${date.day}'),
      onTap: () => onSelect(date),
      child: Container(
        decoration: sel
            ? BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}'),
            SizedBox(
              height: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in {
                    for (final r in on) markColor(context, r),
                  }.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(
    this.label,
    this.icon, {
    this.emi = false,
    this.income = false,
    this.insurance = false,
  });

  final String label;
  final IconData icon;
  final bool emi;
  final bool income;
  final bool insurance;

  @override
  Widget build(BuildContext context) {
    final probe = Recurring(
      name: '',
      amountMinor: 0,
      dayOfMonth: 1,
      category: insurance ? Category.insurance : Category.bills,
      nextDue: DateTime.utc(2000),
      occurrences: 0,
      income: income,
      loanKey: emi ? 'x' : null,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: BillsCalendar.markColor(context, probe)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
