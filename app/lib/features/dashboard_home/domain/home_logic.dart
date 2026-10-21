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

/// A calendar month as `[startMs, endMs)` in local time (FR-17-06).
class MonthRange {
  MonthRange(int year, int month) : start = DateTime(year, month);

  /// The month containing [d].
  factory MonthRange.of(DateTime d) => MonthRange(d.year, d.month);

  /// First instant of the month (local).
  final DateTime start;

  /// First instant of the next month.
  DateTime get end => DateTime(start.year, start.month + 1);

  int get startMs => start.millisecondsSinceEpoch;
  int get endMs => end.millisecondsSinceEpoch;

  MonthRange get previous => MonthRange(start.year, start.month - 1);
  MonthRange get next => MonthRange(start.year, start.month + 1);

  /// `October 2026`.
  String get label => '${_months[start.month - 1]} ${start.year}';

  /// Whether this is the month containing [now].
  bool isCurrent(DateTime now) =>
      now.year == start.year && now.month == start.month;

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
