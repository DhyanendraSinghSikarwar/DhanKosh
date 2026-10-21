import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// The single ledger write path (FR-08-17). Nothing else writes
/// `transactions` or `transaction_sources`.
abstract interface class TransactionRepository {
  /// Ingests [items] in ONE database transaction: rule, tombstone and
  /// processed-id check, dedup, account, row, source row, balance.
  /// Idempotent per (source, sourceMessageId). Rolls back on failure.
  Future<IngestReport> ingestBatch(List<IngestItem> items);

  Future<IngestResult> ingest(IngestItem item);

  /// Adds a hand-entered payment (source MANUAL); dedup may merge it.
  Future<IngestResult> addManual({
    required int amountMinor,
    required TransactionType type,
    required int timestamp,
    int? accountId,
    String? merchant,
    Category category = Category.other,
    String? reference,
    String? note,
  });

  /// Changes the category of [ids]; clears sub/custom category and learns
  /// merchant rules (FR-09-06/07). [customCategoryId] files under OTHER.
  Future<void> setCategory(
    List<int> ids,
    Category category, {
    int? customCategoryId,
    String? subcategory,
  });

  Future<void> setSubcategory(int id, String? subcategory);
  Future<void> setNote(int id, String? note);
  Future<void> setAccount(int id, int? accountId);

  /// Deletes rows and writes tombstones for every source (FR-08-09).
  /// Returns rows deleted.
  Future<int> deleteTransactions(List<int> ids);

  /// Merges a flagged row into its target and deletes it (FR-07-12).
  Future<void> mergeFlagged(int id);

  /// Clears the review flag, keeping both rows (FR-07-12).
  Future<void> keepSeparate(int id);

  /// Sets a manual rule's category on matching past rows (FR-09-09).
  Future<int> applyRuleToPast(MerchantRule rule);

  /// How many past non-transfer rows [rule] would change.
  Future<int> countRuleMatches(MerchantRule rule);

  Future<LedgerTx?> byId(int id);
  Future<List<TxSourceRow>> sourcesOf(int id);

  /// Rows of [accountId] and the accounts merged into it.
  Future<List<int>> idsForAccount(int accountId);

  /// Newest first, [limit] rows.
  Stream<List<LedgerTx>> watch(LedgerFilter filter, {int? limit});
  Stream<List<LedgerTx>> watchRecent(int n);
  Stream<PeriodTotals> watchTotals({
    required int fromMs,
    required int toMs,
    int? accountId,
  });

  /// Flagged rows awaiting a decision (FR-08-19).
  Stream<int> watchReviewCount();
  Stream<List<ReviewPair>> watchReviewPairs();
}
