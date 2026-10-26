import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/analytics/domain/insight_extras.dart';
import 'package:hisaab/features/income_tracking/domain/income_classifier.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

// 2026-10-26 12:00 IST.
final int _now = DateTime.utc(2026, 10, 26, 6, 30).millisecondsSinceEpoch;
final DateTime _today = DateTime.utc(2026, 10, 26);

LedgerTx _tx(
  int id,
  int amount, {
  TransactionType type = TransactionType.debit,
  Category category = Category.other,
  String? merchant,
  String? note,
  int daysAgo = 0,
  bool review = false,
}) =>
    LedgerTx(
      id: id,
      amountMinor: amount,
      currency: 'INR',
      type: type,
      bankName: 'HDFC Bank',
      accountKind: AccountKind.account,
      channel: Channel.upi,
      timestamp: _now - daysAgo * Duration.millisecondsPerDay,
      hasExplicitTime: true,
      category: category,
      transactionHash: 'h$id',
      confidence: 0.9,
      needsReview: review,
      createdAt: _now,
      merchant: merchant,
      note: note,
    );

void main() {
  // FR-18-24
  test('income by source classifies credits and skips refunds', () {
    final l = InsightExtras.incomeBySource([
      _tx(
        1,
        8500000,
        type: TransactionType.credit,
        category: Category.salary,
        merchant: 'ACME Payroll',
      ),
      _tx(
        2,
        12050,
        type: TransactionType.credit,
        category: Category.income,
        note: 'Savings interest credit',
      ),
      _tx(
        3,
        30000,
        type: TransactionType.credit,
        category: Category.income,
        merchant: 'Dividend ITC',
      ),
      _tx(
        4,
        30000,
        type: TransactionType.credit,
        category: Category.income,
        merchant: 'Dividend INFY',
      ),
      _tx(5, 99900, type: TransactionType.credit, category: Category.refund),
      _tx(6, 777700, type: TransactionType.credit, review: true),
      _tx(7, 40000), // debit ignored
    ]);
    expect(l.map((s) => s.bucket), [
      IncomeBucket.salary,
      IncomeBucket.dividend,
      IncomeBucket.savingsInterest,
    ]);
    expect(l[0].totalMinor, 8500000);
    expect(l[1].totalMinor, 60000);
    expect(l[1].count, 2);
    expect(l[2].totalMinor, 12050);
    expect(l[2].label, 'Savings interest');
  });

  // FR-18-25
  test('subscriptions detect monthly charges, sum, skip investments', () {
    final txs = [
      for (var m = 0; m < 3; m++) ...[
        _tx(
          10 + m,
          14900,
          merchant: 'Netflix',
          category: Category.subscriptions,
          daysAgo: 5 + 30 * m,
        ),
        _tx(
          20 + m,
          19900,
          merchant: 'Spotify',
          category: Category.subscriptions,
          daysAgo: 5 + 30 * m,
        ),
        _tx(
          30 + m,
          500000,
          merchant: 'Mutual Fund SIP',
          category: Category.investment,
          daysAgo: 5 + 30 * m,
        ),
      ],
    ];
    final l = InsightExtras.subscriptions(txs, _today);
    expect(l.map((s) => s.name), ['Spotify', 'Netflix']);
    expect(InsightExtras.monthlyTotal(l), 34800);
    expect(InsightExtras.subscriptions(const [], _today), isEmpty);
  });

  // FR-18-26
  test('utilisation percent and bands use integer math', () {
    CardUtil u(int used) =>
        CardUtil(name: 'c', usedMinor: used, limitMinor: 10000000);
    expect(u(0).percent, 0);
    expect(u(2999999).percent, 29);
    expect(u(2999999).band, UtilBand.good);
    expect(u(3000000).band, UtilBand.watch);
    expect(u(6999999).band, UtilBand.watch);
    expect(u(7000000).band, UtilBand.high);
    expect(u(12000000).percent, 120);
    expect(
      const CardUtil(name: 'x', usedMinor: 5, limitMinor: 0).percent,
      0,
    );
  });
}
