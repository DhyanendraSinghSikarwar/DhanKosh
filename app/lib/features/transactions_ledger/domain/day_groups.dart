import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Spent / income for the rows shown (FR-20-18): transfers count 0,
/// investments count as spent.
class LedgerSummary {
  const LedgerSummary({this.spentMinor = 0, this.incomeMinor = 0});
  final int spentMinor;
  final int incomeMinor;
  int get netMinor => incomeMinor - spentMinor;
}

/// INR value of a row; null when it has none (foreign without a rate).
int? inrOf(LedgerTx t) =>
    t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : null);

/// Totals of [rows], review rows excluded.
LedgerSummary summarize(Iterable<LedgerTx> rows) {
  var spent = 0;
  var income = 0;
  for (final t in rows) {
    final v = inrOf(t);
    if (v == null || t.needsReview) continue;
    switch (t.type) {
      case TransactionType.debit:
      case TransactionType.investment:
        spent += v;
      case TransactionType.credit:
        income += v;
      case TransactionType.transfer:
        break;
    }
  }
  return LedgerSummary(spentMinor: spent, incomeMinor: income);
}

/// One local day of rows, newest first (FR-08-02).
class DayGroup {
  const DayGroup(this.day, this.rows, this.summary);
  final DateTime day;
  final List<LedgerTx> rows;
  final LedgerSummary summary;
}

/// Groups newest-first [rows] by local day.
List<DayGroup> groupByDay(List<LedgerTx> rows) {
  final out = <DayGroup>[];
  DateTime? cur;
  var bucket = <LedgerTx>[];
  void flush() {
    if (cur != null) out.add(DayGroup(cur, bucket, summarize(bucket)));
  }

  for (final t in rows) {
    final d = DateTime.fromMillisecondsSinceEpoch(t.timestamp);
    final day = DateTime(d.year, d.month, d.day);
    if (cur != day) {
      flush();
      cur = day;
      bucket = [];
    }
    bucket.add(t);
  }
  flush();
  return out;
}

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = [
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

/// Today / Yesterday / "EEE, d MMM yyyy" (FR-08-02).
String dayLabel(DateTime day, DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final diff =
      today.difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_wd[day.weekday - 1]}, ${day.day} ${_mo[day.month - 1]} ${day.year}';
}
