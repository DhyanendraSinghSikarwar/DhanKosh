import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

/// Spent / income for the rows shown (FR-20-18, ADR-0011): cash basis, so
/// card purchases are left out ([cardMinor]) and card bill payments count;
/// transfers count 0, investments count as spent.
class LedgerSummary {
  const LedgerSummary({
    this.spentMinor = 0,
    this.incomeMinor = 0,
    this.cardMinor = 0,
  });
  final int spentMinor;
  final int incomeMinor;

  /// Card purchases shown beside the headline (FR-10-18).
  final int cardMinor;
  int get netMinor => incomeMinor - spentMinor;
}

/// INR value of a row; null when it has none (foreign without a rate).
int? inrOf(LedgerTx t) =>
    t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : null);

/// Totals of [rows], review rows excluded; [context] pairs card payments.
LedgerSummary summarize(
  Iterable<LedgerTx> rows, {
  Iterable<LedgerTx> context = const [],
}) {
  final c = SpendCalc.totals(rows, context: context);
  return LedgerSummary(
    spentMinor: c.spentMinor + c.investedMinor,
    incomeMinor: c.incomeMinor + c.refundMinor,
    cardMinor: c.cardPurchasesMinor,
  );
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
    if (cur != null) {
      out.add(DayGroup(cur, bucket, summarize(bucket, context: rows)));
    }
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
