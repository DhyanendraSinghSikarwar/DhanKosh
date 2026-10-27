import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Essentials, lifestyle and the rest (FR-18-05).
enum SpendGroup { essentials, lifestyle, other }

/// Tone of an insight (memory 18 section 8): good, warn or info.
enum Tone { good, warn, info }

class MerchantSpend {
  const MerchantSpend({
    required this.name,
    required this.total,
    required this.count,
    required this.category,
  });

  final String name;
  final int total;
  final int count;

  /// Most frequent category (ties: the first one seen).
  final Category category;
}

class MonthFlow {
  const MonthFlow({
    required this.month,
    required this.spent,
    required this.income,
    required this.invested,
    required this.byGroup,
  });

  /// First day of the month (UTC midnight).
  final DateTime month;
  final int spent;
  final int income;
  final int invested;
  final Map<SpendGroup, int> byGroup;
}

/// Heat grid: weekday rows (Monday first) by 3-hour slot columns.
typedef HeatGrid = List<List<int>>;

/// Result of [LedgerMath.heatPeak] (FR-18-06).
class HeatPeak {
  const HeatPeak({
    required this.firstDay,
    required this.lastDay,
    required this.slot,
    required this.peakDay,
  });

  /// Inclusive weekday range, 0 = Monday.
  final int firstDay;
  final int lastDay;

  /// Slot column 0..7.
  final int slot;

  /// The single peak weekday row.
  final int peakDay;
}

/// Sums and groupings over ledger rows, in paise (port of Kotlin
/// `LedgerMath`). Foreign spends use their rupee value (FR-18-18).
abstract final class LedgerMath {
  static const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const slotLabels = ['6a', '9a', '12p', '3p', '6p', '9p', '12a', '3a'];

  /// `inrMinor ?? (INR ? amountMinor : 0)`.
  static int rupees(LedgerTx t) =>
      t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : 0);

  static bool isSpend(LedgerTx t) =>
      t.type == TransactionType.debit && t.category != Category.transfer;
  // Card credits are never income (ADR-0011, FR-10-20).
  static bool isIncome(LedgerTx t) =>
      t.type == TransactionType.credit &&
      t.category != Category.transfer &&
      !SpendCalc.isCard(t);
  static bool isInvest(LedgerTx t) => t.type == TransactionType.investment;

  static int _sum(Iterable<LedgerTx> l) => l.fold(0, (a, t) => a + rupees(t));

  /// Headline expense on the cash basis (ADR-0011): no card purchases, card
  /// bill payments counted. Category views keep [isSpend].
  static int spent(Iterable<LedgerTx> txs) => SpendCalc.totals(txs).spentMinor;
  static int income(Iterable<LedgerTx> txs) {
    final c = SpendCalc.totals(txs);
    return c.incomeMinor + c.refundMinor;
  }

  /// Card purchases of [txs] (shown beside the headline, FR-10-18).
  static int cardPurchases(Iterable<LedgerTx> txs) =>
      SpendCalc.totals(txs).cardPurchasesMinor;
  static int invested(Iterable<LedgerTx> txs) => _sum(txs.where(isInvest));

  static const Set<Category> _essentials = {
    Category.rent,
    Category.bills,
    Category.groceries,
    Category.transport,
    Category.fuel,
    Category.health,
    Category.education,
    Category.insurance,
    Category.emiLoan,
    Category.household,
    Category.taxes,
    Category.fees,
  };
  static const Set<Category> _lifestyle = {
    Category.food,
    Category.shopping,
    Category.entertainment,
    Category.travel,
    Category.subscriptions,
    Category.personalCare,
    Category.gifts,
    Category.donations,
  };

  /// Everything else (other, cash, salary, income, refund, transfer,
  /// investment) is [SpendGroup.other].
  static SpendGroup group(Category c) => _essentials.contains(c)
      ? SpendGroup.essentials
      : _lifestyle.contains(c)
          ? SpendGroup.lifestyle
          : SpendGroup.other;

  /// Spend per category, sum > 0, largest first (stable on ties).
  static List<(Category, int)> byCategory(Iterable<LedgerTx> txs) {
    final m = <Category, int>{};
    for (final t in txs.where(isSpend)) {
      m[t.category] = (m[t.category] ?? 0) + rupees(t);
    }
    return stableSorted<(Category, int)>(
      [
        for (final e in m.entries)
          if (e.value > 0) (e.key, e.value),
      ],
      (a, b) => b.$2.compareTo(a.$2),
    );
  }

  static Map<SpendGroup, int> byGroup(Iterable<LedgerTx> txs) {
    final m = <SpendGroup, int>{};
    for (final t in txs.where(isSpend)) {
      final g = group(t.category);
      m[g] = (m[g] ?? 0) + rupees(t);
    }
    return m;
  }

  /// Spend per `merchant ?? bankName`, largest first.
  static List<MerchantSpend> byMerchant(Iterable<LedgerTx> txs) {
    final groups = <String, List<LedgerTx>>{};
    for (final t in txs.where(isSpend)) {
      groups.putIfAbsent(t.merchant ?? t.bankName, () => []).add(t);
    }
    final out = <MerchantSpend>[];
    for (final e in groups.entries) {
      final counts = <Category, int>{};
      for (final t in e.value) {
        counts[t.category] = (counts[t.category] ?? 0) + 1;
      }
      Category? best;
      var bestN = 0;
      for (final c in counts.entries) {
        if (c.value > bestN) {
          best = c.key;
          bestN = c.value;
        }
      }
      out.add(
        MerchantSpend(
          name: e.key,
          total: _sum(e.value),
          count: e.value.length,
          category: best!,
        ),
      );
    }
    return stableSorted<MerchantSpend>(
      out,
      (a, b) => b.total.compareTo(a.total),
    );
  }

  /// The [n] largest merchants (FR-18-07: 6).
  static List<MerchantSpend> topMerchants(
    Iterable<LedgerTx> txs, {
    int n = 6,
  }) =>
      byMerchant(txs).take(n).toList();

  /// Payments behind a merchant, newest first, at most [limit] (FR-18-07).
  static ({List<LedgerTx> payments, bool truncated}) merchantPayments(
    Iterable<LedgerTx> txs,
    String name, {
    int limit = 60,
  }) {
    final all = stableSorted<LedgerTx>(
      txs.where((t) => isSpend(t) && (t.merchant ?? t.bankName) == name),
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );
    return (payments: all.take(limit).toList(), truncated: all.length > limit);
  }

  /// One [MonthFlow] per entry of [months] (first-of-month days).
  static List<MonthFlow> monthly(
    Iterable<LedgerTx> txs,
    List<DateTime> months, {
    Duration offset = istOffset,
  }) {
    final by = <int, List<LedgerTx>>{};
    for (final t in txs) {
      final d = dayOf(t.timestamp, offset: offset);
      by.putIfAbsent(d.year * 12 + d.month, () => []).add(t);
    }
    return [
      for (final m in months)
        () {
          final l = by[m.year * 12 + m.month] ?? const <LedgerTx>[];
          return MonthFlow(
            month: DateTime.utc(m.year, m.month),
            spent: spent(l),
            income: income(l),
            invested: invested(l),
            byGroup: byGroup(l),
          );
        }(),
    ];
  }

  /// Spend by weekday (rows, Monday first) and 3-hour slot (columns 6a, 9a,
  /// 12p, 3p, 6p, 9p, 12a, 3a); only rows with an explicit time (FR-18-06).
  static HeatGrid heat(Iterable<LedgerTx> txs, {Duration offset = istOffset}) {
    final grid = [for (var i = 0; i < 7; i++) List<int>.filled(8, 0)];
    for (final t in txs.where(isSpend)) {
      if (!t.hasExplicitTime) continue;
      final z = DateTime.fromMillisecondsSinceEpoch(t.timestamp, isUtc: true)
          .add(offset);
      final slot = ((z.hour - 6 + 24) % 24) ~/ 3;
      grid[z.weekday - 1][slot] += rupees(t);
    }
    return grid;
  }

  /// Peak cell; neighbouring days in the slot within 60% of it widen the
  /// range (FR-18-06). Null when the grid is all zero.
  static HeatPeak? heatPeak(HeatGrid grid) {
    var pr = 0;
    var pc = 0;
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < grid[r].length; c++) {
        if (grid[r][c] > grid[pr][pc]) {
          pr = r;
          pc = c;
        }
      }
    }
    final peak = grid[pr][pc];
    if (peak <= 0) return null;
    var a = pr;
    var b = pr;
    while (a > 0 && grid[a - 1][pc] * 10 >= peak * 6) {
      a--;
    }
    while (b < 6 && grid[b + 1][pc] * 10 >= peak * 6) {
      b++;
    }
    return HeatPeak(firstDay: a, lastDay: b, slot: pc, peakDay: pr);
  }

  /// "Mon–Wed, 6p–9p" part of the peak line.
  static String peakText(HeatPeak p) {
    final days = p.firstDay == p.lastDay
        ? dayLabels[p.firstDay]
        : '${dayLabels[p.firstDay]}–${dayLabels[p.lastDay]}';
    return '$days, ${slotLabels[p.slot]}–${slotLabels[(p.slot + 1) % 8]}';
  }

  /// Weekday x slot totals for an optional category cross-filter.
  static Category? topCategoryInCell(
    Iterable<LedgerTx> txs,
    int row,
    int slot, {
    Duration offset = istOffset,
  }) {
    final m = <Category, int>{};
    for (final t in txs.where(isSpend)) {
      if (!t.hasExplicitTime) continue;
      final z = DateTime.fromMillisecondsSinceEpoch(t.timestamp, isUtc: true)
          .add(offset);
      if (z.weekday - 1 != row || ((z.hour - 6 + 24) % 24) ~/ 3 != slot) {
        continue;
      }
      m[t.category] = (m[t.category] ?? 0) + rupees(t);
    }
    Category? best;
    var bestV = 0;
    for (final e in m.entries) {
      if (e.value > bestV) {
        best = e.key;
        bestV = e.value;
      }
    }
    return best;
  }

  /// Weekly buckets: spend per ISO week (Monday start) as `(weekStart,
  /// total)`, oldest first; weeks without spend are omitted.
  static List<(DateTime, int)> weekly(
    Iterable<LedgerTx> txs, {
    Duration offset = istOffset,
  }) {
    final m = <int, int>{};
    for (final t in txs.where(isSpend)) {
      final d = dayOf(t.timestamp, offset: offset);
      final monday = epochDayOf(d) - (d.weekday - 1);
      m[monday] = (m[monday] ?? 0) + rupees(t);
    }
    final keys = m.keys.toList()..sort();
    return [for (final k in keys) (fromEpochDay(k), m[k]!)];
  }

  /// Daily spend per calendar day (FR-18-21 `dailyFor` semantics).
  static Map<DateTime, int> daily(
    Iterable<LedgerTx> txs, {
    Duration offset = istOffset,
  }) {
    final m = <DateTime, int>{};
    for (final t in txs.where(isSpend)) {
      final d = dayOf(t.timestamp, offset: offset);
      m[d] = (m[d] ?? 0) + rupees(t);
    }
    return m;
  }

  /// Spend so far day by day for [month] (cumulative, index 0 = day 1).
  static List<int> cumulative(
    Iterable<LedgerTx> txs,
    DateTime month, {
    Duration offset = istOffset,
  }) {
    final byDay = <int, int>{};
    for (final t in txs.where(isSpend)) {
      final d = dayOf(t.timestamp, offset: offset);
      if (d.year == month.year && d.month == month.month) {
        byDay[d.day] = (byDay[d.day] ?? 0) + rupees(t);
      }
    }
    var run = 0;
    return [
      for (var d = 1; d <= daysInMonth(month.year, month.month); d++)
        run += byDay[d] ?? 0,
    ];
  }

  /// Average of all months except the last (the running one) (FR-18-05).
  static int averageExcludingLast(List<MonthFlow> months) {
    if (months.length < 2) return 0;
    final others = months.sublist(0, months.length - 1);
    return others.fold(0, (a, m) => a + m.spent) ~/ others.length;
  }

  /// Month sheet: signed percent versus the mean of the other months
  /// (`|diff| * 100 / avg`, truncated); null when the average is zero.
  static int? monthVsAverage(List<MonthFlow> months, int index) {
    final others = [
      for (var i = 0; i < months.length; i++)
        if (i != index) months[i],
    ];
    if (others.isEmpty) return null;
    final avg = others.fold(0, (a, m) => a + m.spent) ~/ others.length;
    if (avg <= 0) return null;
    final diff = months[index].spent - avg;
    final pct = diff.abs() * 100 ~/ avg;
    return diff < 0 ? -pct : pct;
  }
}
