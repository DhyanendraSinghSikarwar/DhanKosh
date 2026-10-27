import 'package:hisaab/features/portfolio/domain/net_worth.dart';

/// A dated signed balance effect of one account (paise), epoch day (IST).
class FlowEffect {
  /// Creates an effect.
  const FlowEffect(this.day, this.signedMinor);

  final int day;
  final int signedMinor;
}

/// What the estimate needs of one liquid account: its balance now and every
/// signed effect inside the window.
class AccountFlow {
  /// Creates a flow.
  const AccountFlow({required this.balanceNowMinor, required this.effects});

  final int balanceNowMinor;
  final List<FlowEffect> effects;
}

/// A holding counted from its statement day on.
class HoldingValue {
  /// Creates a value.
  const HoldingValue(this.asOfDay, this.valueMinor);

  final int asOfDay;
  final int valueMinor;
}

/// A history point and whether it is reconstructed (FR-16-05, A6).
class EstimatedPoint {
  /// Creates a point.
  const EstimatedPoint(this.point, {required this.estimated});

  final WorthPoint point;

  /// True when rebuilt from balances, not recorded on that day.
  final bool estimated;
}

/// Epoch day of the last day of [year]-[month] (month 1..12, may overflow).
int monthEndDay(int year, int month) =>
    DateTime.utc(year, month + 1).millisecondsSinceEpoch ~/ 86400000 - 1;

/// Month-end net worth for the last [months] months up to [todayDay] (A6).
///
/// Assets at a month end D = each account's balance now minus its effects
/// after D, plus holdings already stated by D. Liabilities use the recorded
/// point's figure, else [liabilitiesMinor] (card dues cannot be rebuilt).
/// A [recorded] point on D wins and is not flagged. The current month ends at
/// [todayDay]. Oldest first.
List<EstimatedPoint> estimateWorthHistory({
  required int todayDay,
  required List<AccountFlow> accounts,
  required List<HoldingValue> holdings,
  required int liabilitiesMinor,
  List<WorthPoint> recorded = const [],
  int months = 36,
}) {
  final today = DateTime.fromMillisecondsSinceEpoch(
    todayDay * 86400000,
    isUtc: true,
  );
  final byDay = {for (final p in recorded) p.day: p};
  final out = <EstimatedPoint>[];
  for (var i = months - 1; i >= 0; i--) {
    final raw = monthEndDay(today.year, today.month - i);
    final day = raw > todayDay ? todayDay : raw;
    final rec = byDay[day];
    if (rec != null) {
      out.add(EstimatedPoint(rec, estimated: false));
      continue;
    }
    var assets = 0;
    for (final a in accounts) {
      var b = a.balanceNowMinor;
      for (final e in a.effects) {
        if (e.day > day) b -= e.signedMinor;
      }
      if (b > 0) assets += b;
    }
    for (final h in holdings) {
      if (h.asOfDay <= day) assets += h.valueMinor;
    }
    out.add(
      EstimatedPoint(
        WorthPoint(day, assets, liabilitiesMinor),
        estimated: true,
      ),
    );
  }
  return out;
}
