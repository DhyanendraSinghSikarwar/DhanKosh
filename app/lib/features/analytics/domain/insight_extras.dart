import 'package:hisaab/features/income_tracking/domain/income_classifier.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Income of one source bucket (FR-18-24).
class IncomeSource {
  /// Creates a source total.
  const IncomeSource(this.bucket, this.totalMinor, this.count);

  final IncomeBucket bucket;
  final int totalMinor;
  final int count;

  /// Display name.
  String get label => switch (bucket) {
        IncomeBucket.salary => 'Salary',
        IncomeBucket.dividend => 'Dividends',
        IncomeBucket.depositInterest => 'Deposit interest',
        IncomeBucket.savingsInterest => 'Savings interest',
        IncomeBucket.rent => 'Rent',
        IncomeBucket.other => 'Other income',
        IncomeBucket.excluded => 'Excluded',
      };
}

/// A detected subscription (FR-18-25).
class SubscriptionLine {
  /// Creates a line.
  const SubscriptionLine(this.name, this.monthlyMinor);

  final String name;

  /// Paise per month.
  final int monthlyMinor;
}

/// Credit utilisation band (FR-18-26).
enum UtilBand { good, watch, high }

/// Used and limit of one card (FR-18-26).
class CardUtil {
  /// Creates a utilisation.
  const CardUtil({
    required this.name,
    required this.usedMinor,
    required this.limitMinor,
  });

  final String name;
  final int usedMinor;
  final int limitMinor;

  /// Whole percent used, 0..999 (integer math).
  int get percent => limitMinor <= 0 ? 0 : usedMinor * 100 ~/ limitMinor;

  /// Under 30% good, under 70% watch, else high.
  UtilBand get band => percent < 30
      ? UtilBand.good
      : percent < 70
          ? UtilBand.watch
          : UtilBand.high;
}

/// Pure maths of the Income, Subscriptions and Utilisation cards.
abstract final class InsightExtras {
  /// Credits of [txs] grouped by [IncomeClassifier] bucket, largest first.
  /// Review rows, duplicates and the excluded bucket (refunds, transfers,
  /// reimbursements) are left out.
  static List<IncomeSource> incomeBySource(List<LedgerTx> txs) {
    final sums = <IncomeBucket, int>{};
    final counts = <IncomeBucket, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.credit ||
          t.needsReview ||
          t.duplicateOfId != null) {
        continue;
      }
      final b = IncomeClassifier.bucketOf(
        category: t.category,
        merchant: t.merchant,
        note: t.note,
        upiId: t.upiId,
      );
      if (b == IncomeBucket.excluded) continue;
      sums.update(
        b,
        (v) => v + (t.inrMinor ?? t.amountMinor),
        ifAbsent: () => t.inrMinor ?? t.amountMinor,
      );
      counts.update(b, (v) => v + 1, ifAbsent: () => 1);
    }
    return [
      for (final e in sums.entries)
        IncomeSource(e.key, e.value, counts[e.key]!),
    ]..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  }

  /// Detected recurring charges, largest first. Investments and loan EMIs
  /// belong to Portfolio and Loans, so they are left out.
  static List<SubscriptionLine> subscriptions(
    List<LedgerTx> window,
    DateTime today,
  ) =>
      [
        for (final r in RecurringDetector.detect(window, today))
          if (!r.income &&
              r.category != Category.investment &&
              r.category != Category.emiLoan)
            SubscriptionLine(
              r.name,
              r.yearly ? r.amountMinor ~/ 12 : r.amountMinor,
            ),
      ]..sort((a, b) => b.monthlyMinor.compareTo(a.monthlyMinor));

  /// Monthly total of [lines].
  static int monthlyTotal(List<SubscriptionLine> lines) =>
      lines.fold(0, (a, l) => a + l.monthlyMinor);
}
