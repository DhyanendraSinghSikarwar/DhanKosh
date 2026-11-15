import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';

/// Keys read by the native Balance, Budget and Bills widgets (FR-30-16).
/// Every value is already formatted and masked; the native side only draws.
typedef WidgetPayload = Map<String, String>;

String _amount(int minor, {required bool masked}) =>
    formatMoney(Money(minor), masked: masked, showPaise: minor % 100 != 0);

/// Balance widget: the sum of known bank and wallet balances. [balanceMinor]
/// null when no account states a balance yet.
WidgetPayload balancePayload({int? balanceMinor, bool? hidden}) => {
      'bal_caption': 'Bank balance',
      'bal_amount': balanceMinor == null
          ? '—'
          : _amount(balanceMinor, masked: hidden ?? true),
    };

/// Budget widget: what is left of this month's budgets and how much of it is
/// used. [limitMinor] 0 means no budget is set.
WidgetPayload budgetPayload({
  required int limitMinor,
  required int spentMinor,
  bool? hidden,
}) {
  final masked = hidden ?? true;
  if (limitMinor <= 0) {
    return {
      'bud_caption': 'Budget left',
      'bud_left': '—',
      'bud_percent': '0',
      'bud_sub': 'No budget set',
    };
  }
  final left = limitMinor - spentMinor;
  final pct = (spentMinor * 100 ~/ limitMinor).clamp(0, 100);
  return {
    'bud_caption': left < 0 ? 'Over budget' : 'Budget left',
    'bud_left': _amount(left.abs(), masked: masked),
    'bud_percent': '$pct',
    'bud_sub':
        '${_amount(spentMinor, masked: masked)} of ${_amount(limitMinor, masked: masked)}',
  };
}

/// One bill line for the Bills widget.
class WidgetBill {
  /// Creates a line.
  const WidgetBill({
    required this.name,
    required this.amountMinor,
    required this.due,
  });

  /// Bill name.
  final String name;

  /// Amount, paise.
  final int amountMinor;

  /// Next due date.
  final DateTime due;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Bills widget: the next three bills, soonest first.
WidgetPayload billsPayload(List<WidgetBill> bills, {bool? hidden}) {
  final masked = hidden ?? true;
  final sorted = [...bills]..sort((a, b) => a.due.compareTo(b.due));
  final out = <String, String>{'bill_caption': 'Upcoming bills'};
  for (var i = 0; i < 3; i++) {
    out['bill_${i + 1}'] = i < sorted.length
        ? '${sorted[i].name} · '
            '${_amount(sorted[i].amountMinor, masked: masked)} · '
            '${sorted[i].due.day} ${_months[sorted[i].due.month - 1]}'
        : (i == 0 ? 'No bills coming up' : '');
  }
  return out;
}

/// The next due date of a monthly (or yearly in [month]) bill on [dayOfMonth],
/// today or later; the day is clamped to the month's length.
DateTime nextDueOf({
  required int dayOfMonth,
  required DateTime today,
  int? month,
}) {
  DateTime clamp(int y, int m) {
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, dayOfMonth > last ? last : dayOfMonth);
  }

  final t = DateTime(today.year, today.month, today.day);
  if (month != null) {
    final d = clamp(t.year, month);
    return d.isBefore(t) ? clamp(t.year + 1, month) : d;
  }
  final d = clamp(t.year, t.month);
  return d.isBefore(t) ? clamp(t.year, t.month + 1) : d;
}
