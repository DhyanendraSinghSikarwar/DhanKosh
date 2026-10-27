import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Range of the account chart (FR-13-17).
enum SeriesRange {
  sixMonths('6 months'),
  year('Year'),
  allTime('All time');

  const SeriesRange(this.label);

  /// Segment label.
  final String label;
}

/// One month of spend and income, paise.
class MonthPoint {
  /// Creates a point.
  const MonthPoint(this.year, this.month, this.spentMinor, this.incomeMinor);

  final int year;
  final int month;
  final int spentMinor;
  final int incomeMinor;
}

/// Monthly spend (DEBIT + INVESTMENT) and income (CREDIT) of [txs], a point
/// for every month from the range start to [now]'s month; transfers, review
/// rows and rows without an INR value are left out (FR-13-17).
List<MonthPoint> monthSeries(
  List<LedgerTx> txs,
  SeriesRange range,
  DateTime now,
) {
  final usable = txs.where((t) => !t.needsReview && t.inrMinor != null);
  var first = DateTime(now.year, now.month);
  switch (range) {
    case SeriesRange.sixMonths:
      first = DateTime(now.year, now.month - 5);
    case SeriesRange.year:
      first = DateTime(now.year, now.month - 11);
    case SeriesRange.allTime:
      for (final t in usable) {
        final d = DateTime.fromMillisecondsSinceEpoch(t.timestamp);
        final m = DateTime(d.year, d.month);
        if (m.isBefore(first)) first = m;
      }
  }
  final spent = <int, int>{};
  final income = <int, int>{};
  int keyOf(DateTime d) => d.year * 12 + d.month - 1;
  for (final t in usable) {
    final d = DateTime.fromMillisecondsSinceEpoch(t.timestamp);
    final k = keyOf(d);
    if (k < keyOf(first)) continue;
    switch (t.type) {
      case TransactionType.debit:
      case TransactionType.investment:
        spent[k] = (spent[k] ?? 0) + t.inrMinor!;
      case TransactionType.credit:
        income[k] = (income[k] ?? 0) + t.inrMinor!;
      case TransactionType.transfer:
        break;
    }
  }
  final out = <MonthPoint>[];
  for (var k = keyOf(first); k <= keyOf(now); k++) {
    out.add(MonthPoint(k ~/ 12, k % 12 + 1, spent[k] ?? 0, income[k] ?? 0));
  }
  return out;
}
