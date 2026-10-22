import 'package:hisaab/features/loans/domain/emi_pairing.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// A row to turn into a TRANSFER (type and category) with [note].
class TransferMark {
  const TransferMark(this.id, this.note);

  final int id;
  final String note;
}

/// `pairTransfers` (FR-08-14, FR-08-15, memory 08 3.6): money that only moved
/// between the user's own accounts is neither spend nor income.
abstract final class TransferPairing {
  static const int ownWindowMs = 2 * 60 * 60 * 1000;
  static const int cardWindowMs = 5 * 24 * 60 * 60 * 1000;
  static const selfNote = 'Self transfer between your accounts';
  static const cardBillNote = 'Credit card bill payment';

  /// Window to fetch same-amount candidates for [pair] (the widest one).
  static const int fetchWindowMs = cardWindowMs;

  /// Rows to mark for freshly inserted [tx]. [candidates] are other rows of
  /// the same amount (review rows excluded by the caller).
  static List<TransferMark> pair({
    required LedgerTx tx,
    required Iterable<LedgerTx> candidates,
    required Set<int> loanAccountIds,
  }) {
    final accountId = tx.accountId;
    if (accountId == null || tx.needsReview) return const [];
    final others = candidates.where(
      (o) => o.id != tx.id && o.amountMinor == tx.amountMinor && !o.needsReview,
    );
    bool within(LedgerTx o, int ms) => (o.timestamp - tx.timestamp).abs() <= ms;

    if (tx.type == TransactionType.debit || tx.type == TransactionType.credit) {
      final want = tx.type == TransactionType.debit
          ? TransactionType.credit
          : TransactionType.debit;
      for (final o in others) {
        if (o.type == want &&
            o.accountId != null &&
            o.accountId != accountId &&
            o.accountKind == AccountKind.account &&
            tx.accountKind == AccountKind.account &&
            within(o, ownWindowMs)) {
          return [TransferMark(tx.id, selfNote), TransferMark(o.id, selfNote)];
        }
      }
      if (tx.type == TransactionType.debit &&
          tx.accountKind == AccountKind.account) {
        for (final o in others) {
          if (o.type == TransactionType.transfer &&
              (o.accountKind == AccountKind.card ||
                  (o.note?.startsWith(cardBillNote) ?? false)) &&
              within(o, cardWindowMs)) {
            return [TransferMark(tx.id, cardBillNote)];
          }
        }
      }
      if (tx.type == TransactionType.debit) {
        final emi = EmiPairing.pair(
          tx: tx,
          accountId: accountId,
          txOnLoan: loanAccountIds.contains(accountId),
          candidates: others.where((o) => within(o, EmiPairing.windowMs)),
          loanAccountIds: loanAccountIds,
        );
        if (emi != null) return [TransferMark(emi.markTransferId, emi.note)];
      }
      return const [];
    }
    if (tx.type == TransactionType.transfer &&
        tx.accountKind == AccountKind.card) {
      LedgerTx? best;
      for (final o in others) {
        if (o.type == TransactionType.debit &&
            o.accountKind == AccountKind.account &&
            within(o, cardWindowMs) &&
            (best == null ||
                (o.timestamp - tx.timestamp).abs() <
                    (best.timestamp - tx.timestamp).abs())) {
          best = o;
        }
      }
      if (best != null) return [TransferMark(best.id, cardBillNote)];
    }
    return const [];
  }
}
