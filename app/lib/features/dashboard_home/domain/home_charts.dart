import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Cumulative spend per day of a month in paise: index 0 is day 1. Uses
/// [SpendCalc] per day so the line ends at the headline (FR-17-06, B4).
/// Days after [upToDay] repeat nothing: the list stops at [upToDay].
List<int> cumulativeSpend(
  List<LedgerTx> txs, {
  required int daysInMonth,
  int? upToDay,
}) {
  final last = (upToDay ?? daysInMonth).clamp(1, daysInMonth);
  final byDay = <int, List<LedgerTx>>{};
  for (final t in txs) {
    final d = DateTime.fromMillisecondsSinceEpoch(t.timestamp).day;
    byDay.putIfAbsent(d, () => []).add(t);
  }
  var run = 0;
  return [
    for (var d = 1; d <= last; d++)
      run += SpendCalc.netSpent(byDay[d] ?? const <LedgerTx>[], context: txs),
  ];
}

/// Spend of [txs] up to and including [upToDay] of the month (FR-17-06).
int spentUpToDay(List<LedgerTx> txs, int upToDay) => SpendCalc.netSpent(
      [
        for (final t in txs)
          if (DateTime.fromMillisecondsSinceEpoch(t.timestamp).day <= upToDay)
            t,
      ],
      context: txs,
    );

/// One donut slice (FR-17-11).
class CategorySlice {
  /// Creates a slice.
  const CategorySlice(this.label, this.amountMinor, {this.category});

  /// Category or sub-category label; `Others` for the tail.
  final String label;
  final int amountMinor;

  /// Null for Others and sub-category slices.
  final Category? category;
}

List<CategorySlice> _group(
  Iterable<LedgerTx> txs,
  String Function(LedgerTx) keyOf,
  Category? Function(LedgerTx) catOf,
  int top,
) {
  final totals = <String, int>{};
  final cats = <String, Category?>{};
  for (final t in txs) {
    if (!SpendCalc.counts(t) ||
        t.type != TransactionType.debit ||
        t.category == Category.transfer) {
      continue;
    }
    final v = SpendCalc.rupees(t);
    if (v <= 0) continue;
    final k = keyOf(t);
    totals.update(k, (x) => x + v, ifAbsent: () => v);
    cats[k] = catOf(t);
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final out = [
    for (final e in sorted.take(top))
      CategorySlice(e.key, e.value, category: cats[e.key]),
  ];
  final rest = sorted.skip(top).fold<int>(0, (s, e) => s + e.value);
  if (rest > 0) out.add(CategorySlice('Others', rest));
  return out;
}

/// Top 7 categories plus Others; includes card purchases (ADR-0011).
List<CategorySlice> categorySlices(Iterable<LedgerTx> txs) =>
    _group(txs, (t) => t.category.label, (t) => t.category, 7);

/// Sub-categories of [category] (drill-down, B5); no Others cap beyond 7.
List<CategorySlice> subCategorySlices(
  Iterable<LedgerTx> txs,
  Category category,
) =>
    _group(
      txs.where((t) => t.category == category),
      (t) => (t.subcategory ?? '').trim().isEmpty ? 'Other' : t.subcategory!,
      (_) => null,
      7,
    );

/// Whole percent of [part] in [total] (0 when [total] is 0).
int percentOf(int part, int total) => total <= 0 ? 0 : part * 100 ~/ total;

/// Cash flow split bar as parts of a 1000 scale: spent, invested, saved
/// (FR-17-08, B12). Empty without income.
({int spent, int invested, int saved}) splitBar({
  required int incomeMinor,
  required int spentMinor,
  required int investedMinor,
}) {
  if (incomeMinor <= 0) return (spent: 0, invested: 0, saved: 0);
  int part(int v) => (v * 1000 ~/ incomeMinor).clamp(0, 1000);
  final s = part(spentMinor);
  final i = part(investedMinor).clamp(0, 1000 - s);
  return (spent: s, invested: i, saved: 1000 - s - i);
}

/// Kind of an Upcoming row (FR-17-09).
enum UpcomingKind { bill, emi, insurance, card, income }

/// One Upcoming row.
class UpcomingRow {
  /// Creates a row.
  const UpcomingRow({
    required this.name,
    required this.amountMinor,
    required this.days,
    required this.kind,
  });

  final String name;
  final int amountMinor;

  /// Days from today.
  final int days;
  final UpcomingKind kind;
}

/// Rows due in 0..[within] days, soonest first, at most [limit]
/// (FR-17-09: bills, EMIs, insurance renewals, card dues).
List<UpcomingRow> upcomingRows(
  List<UpcomingRow> all, {
  int within = 7,
  int limit = 5,
}) =>
    ([
      for (final r in all)
        if (r.days >= 0 && r.days <= within) r,
    ]..sort((a, b) => a.days.compareTo(b.days)))
        .take(limit)
        .toList();

/// `Due today`, `Tomorrow` or `In n days` (FR-17-09).
String upcomingWhen(int days) => days <= 0
    ? 'Due today'
    : days == 1
        ? 'Tomorrow'
        : 'In $days days';
