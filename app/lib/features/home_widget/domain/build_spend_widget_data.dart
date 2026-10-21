import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/home_widget/domain/spend_widget_data.dart';

/// Caption above today's amount.
const widgetTodayCaption = 'Spent today';

/// Caption above the month amount.
const widgetMonthCaption = 'This month';

/// Formats one total: en-IN, paise only when non-zero (FR-30-05).
String widgetAmountText(int minor, {required bool masked}) =>
    formatMoney(Money(minor), masked: masked, showPaise: minor % 100 != 0);

/// Builds the widget snapshot. [hidden] null (setting not read yet) masks
/// the amounts (FR-30-06). Pure.
SpendWidgetData buildSpendWidgetData({
  required int todayMinor,
  required int monthMinor,
  required DateTime now,
  bool? hidden,
}) {
  final masked = hidden ?? true;
  return SpendWidgetData(
    todayMinor: todayMinor,
    monthMinor: monthMinor,
    hidden: masked,
    todayText: widgetAmountText(todayMinor, masked: masked),
    monthText: widgetAmountText(monthMinor, masked: masked),
    todayCaption: widgetTodayCaption,
    monthCaption: widgetMonthCaption,
    updatedAt: now,
  );
}
