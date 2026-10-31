import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `₹1,23,456.00`, or `₹••••` when [masked].
String cardMoney(int minor, {bool masked = false}) =>
    formatMoney(Money(minor), masked: masked);

/// `5 Nov` for an IST epoch day.
String cardDate(int epochDay) {
  final d = DateTime.utc(1970).add(Duration(days: epochDay));
  return '${d.day} ${_months[d.month - 1]}';
}

/// Days from [now] (epoch ms) to [dueDay]; negative when overdue.
int daysToDue(int dueDay, int now) => dueDay - CardDay.ofMs(now);

/// `Overdue`, `Due today`, `Due tomorrow` or `Due in n days` (FR-14-13).
String dueLabel(int days) => days < 0
    ? 'Overdue'
    : days == 0
        ? 'Due today'
        : days == 1
            ? 'Due tomorrow'
            : 'Due in $days days';

/// `5 Nov 2026` for an IST epoch day.
String cardDateYear(int epochDay) {
  final d = DateTime.utc(1970).add(Duration(days: epochDay));
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// `₹1,23,456` (no paise), or `₹••••` when [masked].
String cardWhole(int minor, {bool masked = false}) =>
    formatMoney(Money(minor), masked: masked, showPaise: false);

/// Compact limit: `2.0L`, `50K`, `800` (paise in); `••••` when [masked].
String cardCompact(int minor, {bool masked = false}) {
  if (masked) return '••••';
  final v = minor / 100;
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).round()}K';
  return v.round().toString();
}
