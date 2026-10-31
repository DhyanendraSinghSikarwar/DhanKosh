import 'package:flutter/material.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';
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

/// Month name, e.g. `November`.
String monthName(int month) => _names[month - 1];

/// Month stepper, then a card with the Monday-first month grid (rounded
/// day tiles with coloured dots) and a legend; per-day selection
/// (FR-12-09, 10).
class BillsCalendar extends StatelessWidget {
  /// Creates the calendar.
  const BillsCalendar({
    required this.items,
    required this.month,
    required this.selected,
    required this.onMonth,
    required this.onSelect,
    this.cardDays = const {},
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

  /// Days (UTC) a card bill is due.
  final Set<DateTime> cardDays;

  /// Colour of a card-due dot.
  static const Color cardColor = AppIcons.violet;

  /// Dot colour of [r]: EMI amber, income mint, insurance teal, else red.
  static Color markColor(BuildContext context, Recurring r) {
    if (r.income) return AppIcons.mint;
    if (r.loanKey != null) return AppIcons.amber;
    if (r.category == Category.insurance) return AppIcons.teal;
    return AppIcons.red;
  }

  @override
  Widget build(BuildContext context) {
    final len = DateTime.utc(month.year, month.month + 1, 0).day;
    final lead = (month.weekday + 6) % 7; // Monday first
    final cells = <Widget>[
      for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
        Center(child: Text(d, style: MockText.small(context))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= len; d++)
        _day(context, DateTime.utc(month.year, month.month, d)),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              IconButton(
                key: const Key('cal-prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonth(-1),
              ),
              Expanded(
                child: Text(
                  '${monthName(month.month)} ${month.year}',
                  key: const Key('cal-title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const Key('cal-next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonth(1),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                physics: const NeverScrollableScrollPhysics(),
                children: cells,
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: LegendRow([
                  LegendItem('EMI', AppIcons.amber),
                  LegendItem('Card due', cardColor),
                  LegendItem('Bill', AppIcons.red),
                  LegendItem('Income', AppIcons.mint),
                  LegendItem('Insurance', AppIcons.teal),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _day(BuildContext context, DateTime date) {
    final on = [
      for (final r in items)
        if (RecurringDetector.occursOn(r, date)) r,
    ];
    final colors = <Color>{
      for (final r in on) markColor(context, r),
      if (cardDays.contains(date)) cardColor,
    };
    final scheme = Theme.of(context).colorScheme;
    final sel = selected == date;
    return InkWell(
      key: Key('cal-day-${date.day}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => onSelect(date),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: sel ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in colors.take(3))
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
