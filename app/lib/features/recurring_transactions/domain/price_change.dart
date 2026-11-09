import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// A repeating payment that was charged a different amount this time
/// (FR-12-21). Money in paise.
class PriceChange {
  /// Creates a change.
  const PriceChange({
    required this.name,
    required this.oldMinor,
    required this.newMinor,
    required this.txId,
  });

  final String name;
  final int oldMinor;
  final int newMinor;

  /// The charge that changed.
  final int txId;
}

/// Finds subscription-style price changes in the ledger. Pure.
abstract final class PriceChanges {
  /// Newest charge must be this recent.
  static const recentDays = 10;

  /// Smallest change that counts, per cent.
  static const minPercent = 5;

  /// Biggest change that counts, per cent (more is a different purchase).
  static const maxPercent = 100;

  /// A merchant paid in at least three different months with the same amount
  /// (within 2 per cent) until the newest charge, which differs.
  static List<PriceChange> detect(List<LedgerTx> txs, DateTime today) {
    final from = today.subtract(const Duration(days: 130));
    final groups = <String, List<LedgerTx>>{};
    for (final t in txs) {
      if (t.type != TransactionType.debit || t.currency != 'INR') continue;
      if (t.needsReview || t.excluded || t.duplicateOfId != null) continue;
      if (Ist.dateOf(t.timestamp).isBefore(from)) continue;
      final k = (t.merchant ?? t.upiId)?.trim().toLowerCase();
      if (k != null && k.length >= 2) (groups[k] ??= []).add(t);
    }
    final out = <PriceChange>[];
    for (final g in groups.values) {
      g.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (g.length < 3) continue;
      final newest = g.last;
      if (today.difference(Ist.dateOf(newest.timestamp)).inDays > recentDays) {
        continue;
      }
      final before = g.sublist(0, g.length - 1);
      final base = before.last.amountMinor;
      if (base <= 0) continue;
      final stable =
          before.every((t) => (t.amountMinor - base).abs() * 50 <= base);
      final months = {
        for (final t in before)
          Ist.dateOf(t.timestamp).year * 12 + Ist.dateOf(t.timestamp).month,
      };
      if (!stable || months.length < 2) continue;
      final pct = (newest.amountMinor - base).abs() * 100 ~/ base;
      if (pct < minPercent || pct > maxPercent) continue;
      out.add(
        PriceChange(
          name: newest.title,
          oldMinor: base,
          newMinor: newest.amountMinor,
          txId: newest.id,
        ),
      );
    }
    return out;
  }
}
