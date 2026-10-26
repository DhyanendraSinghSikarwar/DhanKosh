import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Result of a round-up calculation (FR-36-05).
class RoundUpSummary {
  /// Creates a summary.
  const RoundUpSummary({required this.totalMinor, required this.count});

  /// Sum of the round-ups, paise.
  final int totalMinor;

  /// Expenses that had a round-up above 0.
  final int count;
}

/// Virtual round-ups: for each expense, the gap to the next multiple of the
/// step. Tracking only, never moves money, computed on read (FR-36-05).
abstract final class RoundUp {
  /// Allowed steps in rupees.
  static const steps = [10, 50, 100];

  /// Gap from [amountMinor] up to the next multiple of [stepRupees]; 0 when
  /// already a multiple.
  static int amountFor(int amountMinor, int stepRupees) {
    final step = stepRupees * 100;
    if (step <= 0 || amountMinor <= 0) return 0;
    return (step - amountMinor % step) % step;
  }

  /// FR-36-05: round-ups over expense rows of [txs] dated in
  /// `[fromMs, toMs)`. Counts DEBIT rows with an INR value that are not
  /// transfers, under review or duplicates.
  static RoundUpSummary total(
    List<LedgerTx> txs,
    int stepRupees,
    int fromMs,
    int toMs,
  ) {
    var sum = 0;
    var n = 0;
    for (final t in txs) {
      if (t.type != TransactionType.debit ||
          t.needsReview ||
          t.duplicateOfId != null ||
          t.category == Category.transfer ||
          t.timestamp < fromMs ||
          t.timestamp >= toMs) {
        continue;
      }
      final inr = t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : null);
      if (inr == null) continue;
      final r = amountFor(inr, stepRupees);
      if (r > 0) {
        sum += r;
        n++;
      }
    }
    return RoundUpSummary(totalMinor: sum, count: n);
  }
}
