import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// One stacked month bar (FR-18-05, FR-37-04). Paise.
class StackedMonth {
  /// Creates a bar.
  const StackedMonth({
    required this.month,
    required this.essentials,
    required this.lifestyle,
    required this.other,
  });

  /// First day of the month.
  final DateTime month;
  final int essentials;
  final int lifestyle;
  final int other;

  /// Bar height.
  int get total => essentials + lifestyle + other;
}

/// Tap-selection state of the Analysis charts (FR-18-20, FR-18-21).
class ChartSelection {
  /// Creates a selection.
  const ChartSelection({
    this.category,
    this.subcategory,
    this.heatDay,
    this.heatSlot,
  });

  /// No filter.
  static const none = ChartSelection();

  /// Selected donut slice (null: all).
  final Category? category;

  /// Selected sub-category inside [category] (the drill level).
  final String? subcategory;

  /// Heat cell weekday 0..6 (Monday first) and slot 0..7.
  final int? heatDay;
  final int? heatSlot;

  bool get hasHeat => heatDay != null && heatSlot != null;
  bool get isEmpty => category == null && !hasHeat;

  /// Taps [c]: select, or clear when already selected.
  ChartSelection tapCategory(Category c) => category == c && subcategory == null
      ? ChartSelection(heatDay: heatDay, heatSlot: heatSlot)
      : ChartSelection(category: c, heatDay: heatDay, heatSlot: heatSlot);

  /// Taps sub-category [s] while drilled into [category].
  ChartSelection tapSub(String s) => ChartSelection(
        category: category,
        subcategory: subcategory == s ? null : s,
        heatDay: heatDay,
        heatSlot: heatSlot,
      );

  /// Back one drill level.
  ChartSelection back() => subcategory != null
      ? ChartSelection(
          category: category,
          heatDay: heatDay,
          heatSlot: heatSlot,
        )
      : ChartSelection(heatDay: heatDay, heatSlot: heatSlot);

  /// Taps a heat cell; the same cell clears (FR-18-22).
  ChartSelection tapHeat(int day, int slot) =>
      heatDay == day && heatSlot == slot
          ? ChartSelection(category: category, subcategory: subcategory)
          : ChartSelection(
              category: category,
              subcategory: subcategory,
              heatDay: day,
              heatSlot: slot,
            );
}

/// Pure chart-series builders (paise).
abstract final class ChartData {
  /// Stacked bars from [months]; the three groups sum to `spent`.
  static List<StackedMonth> stacked(List<MonthFlow> months) => [
        for (final m in months)
          StackedMonth(
            month: m.month,
            essentials: m.byGroup[SpendGroup.essentials] ?? 0,
            lifestyle: m.byGroup[SpendGroup.lifestyle] ?? 0,
            other: m.byGroup[SpendGroup.other] ?? 0,
          ),
      ];

  /// Average total of all bars but the last (partial) one.
  static int averageExcludingLast(List<StackedMonth> bars) {
    if (bars.length < 2) return 0;
    final h = bars.sublist(0, bars.length - 1);
    return h.fold(0, (a, b) => a + b.total) ~/ h.length;
  }

  /// Heat cell of [t]: (weekday 0..6, slot 0..7), null without a time.
  static (int, int)? heatCell(LedgerTx t, {Duration offset = istOffset}) {
    if (!t.hasExplicitTime) return null;
    final z = DateTime.fromMillisecondsSinceEpoch(t.timestamp, isUtc: true)
        .add(offset);
    return (z.weekday - 1, ((z.hour - 6 + 24) % 24) ~/ 3);
  }

  /// Rows matching [s] (category, sub-category; heat only when [withHeat]).
  static List<LedgerTx> select(
    Iterable<LedgerTx> txs,
    ChartSelection s, {
    bool withHeat = true,
  }) =>
      [
        for (final t in txs)
          if ((s.category == null || t.category == s.category) &&
              (s.subcategory == null ||
                  (t.subcategory ?? 'Other') == s.subcategory) &&
              (!withHeat ||
                  !s.hasHeat ||
                  heatCell(t) == (s.heatDay, s.heatSlot)))
            t,
      ];

  /// Spend of [category] per sub-category, largest first; no sub-category
  /// files under "Other".
  static List<(String, int)> subcategories(
    Iterable<LedgerTx> txs,
    Category category,
  ) {
    final m = <String, int>{};
    for (final t in txs.where((t) => LedgerMath.isSpend(t))) {
      if (t.category != category) continue;
      final k = t.subcategory ?? 'Other';
      m[k] = (m[k] ?? 0) + LedgerMath.rupees(t);
    }
    final l = [
      for (final e in m.entries)
        if (e.value > 0) (e.key, e.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return l;
  }

  /// Spend of [category] for each of [months] (first-of-month days).
  static List<(DateTime, int)> categoryMonthly(
    Iterable<LedgerTx> txs,
    Category category,
    List<DateTime> months, {
    Duration offset = istOffset,
  }) {
    final by = <int, int>{};
    for (final t in txs.where(LedgerMath.isSpend)) {
      if (t.category != category) continue;
      final d = dayOf(t.timestamp, offset: offset);
      final k = d.year * 12 + d.month;
      by[k] = (by[k] ?? 0) + LedgerMath.rupees(t);
    }
    return [for (final m in months) (m, by[m.year * 12 + m.month] ?? 0)];
  }

  /// Card purchases (debits on cards) beside the headline (ADR-0011).
  static int cardPurchases(Iterable<LedgerTx> txs) => txs
      .where((t) => LedgerMath.isSpend(t) && t.accountKind == AccountKind.card)
      .fold(0, (a, t) => a + LedgerMath.rupees(t));

  /// Diverging bar fractions in -1..1 (percent capped at +-50, FR-18-16).
  static List<double> divergence(List<CategoryChange> changes) =>
      [for (final c in changes) c.barPercent / 50];

  /// Sankey layout: node heights as fractions of the larger side.
  static List<double> fractions(List<int> values, int scale) =>
      [for (final v in values) scale <= 0 ? 0 : v / scale];
}
