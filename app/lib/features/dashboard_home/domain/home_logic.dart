import 'package:hisaab/features/accounts_management/domain/account.dart';

/// Greeting by local hour (FR-17-03): 5-11 morning, 12-16 afternoon,
/// 17-21 evening, otherwise night.
String greeting(int hour) {
  if (hour >= 5 && hour <= 11) return 'Good morning';
  if (hour >= 12 && hour <= 16) return 'Good afternoon';
  if (hour >= 17 && hour <= 21) return 'Good evening';
  return 'Good night';
}

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

/// A budget month as `[startMs, endMs)` in local time (FR-17-06, FR-10-25).
/// It runs from the cycle day of one month to the day before the cycle day of
/// the next; with the default cycle day 1 it is the calendar month. A cycle
/// day past the end of a short month falls on that month's last day.
class MonthRange {
  /// The cycle starting in [month] of [year].
  MonthRange(int year, int month) : start = _startOf(year, month);

  /// The cycle containing [d].
  factory MonthRange.of(DateTime d) {
    final here = _startOf(d.year, d.month);
    final from = DateTime(d.year, d.month, d.day);
    return from.isBefore(here)
        ? MonthRange(d.year, d.month - 1)
        : MonthRange(d.year, d.month);
  }

  /// Day each cycle starts on, 1 to 31 (FR-10-25). Set from the setting.
  static int cycleDay = 1;

  static DateTime _startOf(int year, int month) {
    final first = DateTime(year, month);
    final len = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, cycleDay < len ? cycleDay : len);
  }

  /// First instant of the cycle (local).
  final DateTime start;

  /// First instant of the next cycle.
  DateTime get end => _startOf(start.year, start.month + 1);

  int get startMs => start.millisecondsSinceEpoch;
  int get endMs => end.millisecondsSinceEpoch;

  MonthRange get previous => MonthRange(start.year, start.month - 1);
  MonthRange get next => MonthRange(start.year, start.month + 1);

  /// `October 2026`, or `25 Oct - 24 Nov` when the cycle does not start on
  /// the 1st.
  String get label {
    if (cycleDay == 1) return '${_months[start.month - 1]} ${start.year}';
    final last = end.subtract(const Duration(days: 1));
    String d(DateTime x) => '${x.day} ${_months[x.month - 1].substring(0, 3)}';
    return '${d(start)} - ${d(last)}';
  }

  /// Whether this is the cycle containing [now].
  bool isCurrent(DateTime now) => MonthRange.of(now) == this;

  // Value equality on final fields only.
  // ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes
  @override
  bool operator ==(Object other) => other is MonthRange && other.start == start;

  @override
  int get hashCode => start.hashCode;
}

/// Sum of known balances of liquid accounts (paise); null if none known.
int? liquidBalanceMinor(List<AccountWithActivity> accounts) {
  int? total;
  for (final a in accounts) {
    if (!a.account.isLiquid) continue;
    final b = a.currentBalanceMinor;
    if (b != null) total = (total ?? 0) + b;
  }
  return total;
}
