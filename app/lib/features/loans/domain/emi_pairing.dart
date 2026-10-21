import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Result of [EmiPairing.pair]: transaction [markTransferId] becomes a
/// TRANSFER with [note] so the EMI is counted once.
class EmiPair {
  const EmiPair({required this.markTransferId, required this.note});

  final int markTransferId;
  final String note;
}

/// `pairEmi` (FR-08-15, memory 15 3.9): a loan-account EMI row and the bank
/// debit of the same amount within +-3 days. The bank debit stays the spend.
abstract final class EmiPairing {
  static const windowMs = 3 * 24 * 60 * 60 * 1000;
  static const note = 'EMI also debited from your bank account';

  /// [tx] is a freshly inserted DEBIT on [accountId]; [txOnLoan] says whether
  /// that account is a loan account; [candidates] are other rows (any amount),
  /// with [loanAccountIds] telling which accounts are loans.
  static EmiPair? pair({
    required LedgerTx tx,
    required int accountId,
    required bool txOnLoan,
    required Iterable<LedgerTx> candidates,
    required Set<int> loanAccountIds,
  }) {
    if (tx.type != TransactionType.debit) return null;
    if (txOnLoan && tx.category != Category.emiLoan) return null;
    for (final o in candidates) {
      final other = o.accountId;
      if (other == null || other == accountId) continue;
      if (o.id == tx.id ||
          o.type != TransactionType.debit ||
          o.amountMinor != tx.amountMinor ||
          (o.timestamp - tx.timestamp).abs() > windowMs) {
        continue;
      }
      final otherOnLoan = loanAccountIds.contains(other);
      final loanSide = txOnLoan ? tx : o;
      final bankSide = txOnLoan ? o : tx;
      if (otherOnLoan != txOnLoan &&
          loanSide.category == Category.emiLoan &&
          (bankSide.category == Category.emiLoan ||
              bankSide.channel == Channel.autoDebit)) {
        return EmiPair(markTransferId: txOnLoan ? tx.id : o.id, note: note);
      }
    }
    return null;
  }
}
