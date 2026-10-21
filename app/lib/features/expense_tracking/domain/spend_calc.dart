import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// The three documented spend calculators (FR-10-01..03). Money in paise.
abstract final class SpendCalc {
  /// `inrMinor`, or `amountMinor` for INR, else 0 (FR-10-02).
  static int rupees(LedgerTx t) =>
      t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : 0);

  /// Rows counted in any total (FR-10-03).
  static bool counts(LedgerTx t) => !t.needsReview && t.duplicateOfId == null;

  /// DEBIT, not TRANSFER.
  static int ledgerSpent(Iterable<LedgerTx> txs) => txs
      .where(
        (t) =>
            counts(t) &&
            t.type == TransactionType.debit &&
            t.category != Category.transfer,
      )
      .fold(0, (s, t) => s + rupees(t));

  /// [ledgerSpent] minus REFUND credits, floored at 0.
  static int netSpent(Iterable<LedgerTx> txs) {
    final refunds = txs
        .where(
          (t) =>
              counts(t) &&
              t.type == TransactionType.credit &&
              t.category == Category.refund,
        )
        .fold(0, (s, t) => s + rupees(t));
    final v = ledgerSpent(txs) - refunds;
    return v < 0 ? 0 : v;
  }

  /// DEBIT plus INVESTMENT, not TRANSFER.
  static int outflow(Iterable<LedgerTx> txs) => txs
      .where(
        (t) =>
            counts(t) &&
            (t.type == TransactionType.debit ||
                t.type == TransactionType.investment) &&
            t.category != Category.transfer,
      )
      .fold(0, (s, t) => s + rupees(t));

  /// Non-INR rows without a rate, counted as 0 (FR-10-02 "needs a rate").
  static int unpricedCount(Iterable<LedgerTx> txs) => txs
      .where((t) => counts(t) && t.currency != 'INR' && t.inrMinor == null)
      .length;

  /// `(spent - previous) * 100 ~/ previous`, null when previous is 0.
  static int? changePercent(int spent, int previousSamePeriod) =>
      previousSamePeriod == 0
          ? null
          : (spent - previousSamePeriod) * 100 ~/ previousSamePeriod;
}
