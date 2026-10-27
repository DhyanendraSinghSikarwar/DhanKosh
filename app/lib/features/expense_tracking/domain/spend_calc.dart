import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transfer_pairing.dart';
import 'package:parser_core/parser_core.dart';

/// The three documented spend calculators (FR-10-01..03). Money in paise.
abstract final class SpendCalc {
  /// `inrMinor`, or `amountMinor` for INR, else 0 (FR-10-02).
  static int rupees(LedgerTx t) =>
      t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : 0);

  /// Rows counted in any total (FR-10-03).
  static bool counts(LedgerTx t) => !t.needsReview && t.duplicateOfId == null;

  /// Cash-basis spend (ADR-0011): account debits and card bill payments, no
  /// card purchases, no own transfers. [context] pairs card payments.
  static int ledgerSpent(
    Iterable<LedgerTx> txs, {
    Iterable<LedgerTx> context = const [],
  }) =>
      totals(txs, context: context).spentMinor;

  /// [ledgerSpent] minus account-side REFUND credits, floored at 0.
  static int netSpent(
    Iterable<LedgerTx> txs, {
    Iterable<LedgerTx> context = const [],
  }) =>
      totals(txs, context: context).netSpentMinor;

  /// [ledgerSpent] plus INVESTMENT rows.
  static int outflow(
    Iterable<LedgerTx> txs, {
    Iterable<LedgerTx> context = const [],
  }) {
    final c = totals(txs, context: context);
    return c.spentMinor + c.investedMinor;
  }

  /// Non-INR rows without a rate, counted as 0 (FR-10-02 "needs a rate").
  static int unpricedCount(Iterable<LedgerTx> txs) => txs
      .where((t) => counts(t) && t.currency != 'INR' && t.inrMinor == null)
      .length;

  /// `(spent - previous) * 100 ~/ previous`, null when previous is 0.
  static int? changePercent(int spent, int previousSamePeriod) =>
      previousSamePeriod == 0
          ? null
          : (spent - previousSamePeriod) * 100 ~/ previousSamePeriod;

  // ---- ADR-0011: cash basis (FR-10-18..22) ---------------------------------

  /// A row on a credit card (or debit card) account.
  static bool isCard(LedgerTx t) => t.accountKind == AccountKind.card;

  /// Bank-side leg of a credit card bill payment (FR-10-19).
  static bool isBankPaymentLeg(LedgerTx t) =>
      t.type == TransactionType.transfer &&
      !isCard(t) &&
      (t.note?.startsWith(TransferPairing.cardBillNote) ?? false);

  /// Card-side payment record (a TRANSFER on a card row).
  static bool isCardPaymentRecord(LedgerTx t) =>
      t.type == TransactionType.transfer && isCard(t);

  /// Card-side payment records with no bank leg in [pool]: these count
  /// instead of the missing leg (FR-10-19). One bank leg pairs one record.
  static Set<int> unpairedCardPayments(
    Iterable<LedgerTx> records,
    Iterable<LedgerTx> pool,
  ) {
    final legs = pool.where((t) => counts(t) && isBankPaymentLeg(t)).toList();
    final used = <int>{};
    final out = <int>{};
    final sorted = records
        .where((t) => counts(t) && isCardPaymentRecord(t))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final r in sorted) {
      LedgerTx? best;
      for (final l in legs) {
        if (used.contains(l.id) ||
            l.amountMinor != r.amountMinor ||
            (l.timestamp - r.timestamp).abs() > TransferPairing.cardWindowMs) {
          continue;
        }
        if (best == null ||
            (l.timestamp - r.timestamp).abs() <
                (best.timestamp - r.timestamp).abs()) {
          best = l;
        }
      }
      if (best == null) {
        out.add(r.id);
      } else {
        used.add(best.id);
      }
    }
    return out;
  }

  /// Headline totals of [rows] on the cash basis (ADR-0011). [context] are
  /// extra rows (outside the period) used only to pair card payments.
  /// [cardAsSpend] counts card purchases as spend (a card-only scope).
  static CashTotals totals(
    Iterable<LedgerTx> rows, {
    Iterable<LedgerTx> context = const [],
    bool cardAsSpend = false,
  }) {
    final list = rows.where(counts).toList();
    final unpaired = unpairedCardPayments(list, [...list, ...context]);
    var spent = 0;
    var cardPurchases = 0;
    var cardPayments = 0;
    var invested = 0;
    var income = 0;
    var refund = 0;
    var cardRefunds = 0;
    for (final t in list) {
      final v = rupees(t);
      switch (t.type) {
        case TransactionType.debit:
          if (t.category == Category.transfer) break;
          if (isCard(t)) {
            cardPurchases += v;
            if (cardAsSpend) spent += v;
          } else {
            spent += v;
          }
        case TransactionType.investment:
          invested += v;
        case TransactionType.credit:
          if (t.category == Category.transfer) break;
          if (isCard(t)) {
            if (t.category == Category.refund) cardRefunds += v;
          } else if (t.category == Category.refund) {
            refund += v;
          } else {
            income += v;
          }
        case TransactionType.transfer:
          if (isBankPaymentLeg(t) ||
              (isCardPaymentRecord(t) && unpaired.contains(t.id))) {
            if (!cardAsSpend) spent += v;
            cardPayments += v;
          }
      }
    }
    return CashTotals(
      spentMinor: spent,
      cardPurchasesMinor: cardPurchases,
      cardPaymentsMinor: cardPayments,
      investedMinor: invested,
      incomeMinor: income,
      refundMinor: refund,
      cardRefundMinor: cardRefunds,
      count: list.length,
    );
  }
}

/// Result of [SpendCalc.totals], paise.
class CashTotals {
  const CashTotals({
    this.spentMinor = 0,
    this.cardPurchasesMinor = 0,
    this.cardPaymentsMinor = 0,
    this.investedMinor = 0,
    this.incomeMinor = 0,
    this.refundMinor = 0,
    this.cardRefundMinor = 0,
    this.count = 0,
  });

  /// Headline expense: account spends plus card bill payments.
  final int spentMinor;

  /// Card purchases (listed and categorised, not in [spentMinor]).
  final int cardPurchasesMinor;

  /// Card bill payments inside [spentMinor].
  final int cardPaymentsMinor;
  final int investedMinor;

  /// Account credits except refunds and transfers; never card credits.
  final int incomeMinor;

  /// Account-side refunds.
  final int refundMinor;

  /// Card refunds: reduce the category on the card, not income.
  final int cardRefundMinor;
  final int count;

  int get netSpentMinor {
    final v = spentMinor - refundMinor;
    return v < 0 ? 0 : v;
  }

  int get outMinor => spentMinor + investedMinor;
  int get netMinor => incomeMinor - spentMinor;
}
