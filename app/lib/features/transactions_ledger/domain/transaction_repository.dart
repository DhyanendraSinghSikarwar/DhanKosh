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

  /// Adds a payment the user confirmed from a message nothing could read
  /// (F-38, FR-38-11). It goes through the same ingest as the parsers, with
  /// the message's own source and id, so dedup applies and the same message
  /// read later by a parser is not booked a second time.
  Future<IngestResult> addFromMessage({
    required Source source,
    required String sourceMessageId,
    required String sender,
    required String rawText,
    required int amountMinor,
    required TransactionType type,
    required int timestamp,
    String currency = 'INR',
    int? accountId,
    String? merchant,
    String? upiId,
    Category category = Category.other,
    String? reference,
    String? note,
    Channel channel = Channel.other,
  });

  /// FR-08-13: two linked TRANSFER legs (`xfer-out:` / `xfer-in:` sources);
  /// one account may be null when the other side is not tracked. Returns the
  /// leg ids. A later bank message for the same payment folds into the leg.
  Future<List<int>> addOwnTransfer({
    required int? fromAccountId,
    required int? toAccountId,
    required int amountMinor,
    required int timestamp,
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

  /// Replaces the tags of [id] (FR-08-29): trimmed, no duplicates ignoring
  /// case, at most 10, each up to 30 characters.
  Future<void> setTags(int id, List<String> tags);

  /// Every tag in use, most used first.
  Future<List<String>> allTags();

  /// Shows [alias] instead of the payee's name on every row of that payee;
  /// null or blank removes it (FR-09-20).
  Future<void> setMerchantAlias(int id, String? alias);

  /// Leaves [ids] out of (or back in) every total; balances are unchanged
  /// (FR-10-24).
  Future<void> setExcluded(List<int> ids, {required bool excluded});

  /// Moves a row to [accountId]; [rememberPayee] files later rows of the same
  /// payee under it too (FR-08-24).
  Future<void> setAccount(int id, int? accountId, {bool rememberPayee = false});

  /// Deletes rows and writes tombstones for every source (FR-08-09).
  /// Returns rows deleted.
  Future<int> deleteTransactions(List<int> ids);

  /// Merges a flagged row into its target and deletes it (FR-07-12).
  Future<void> mergeFlagged(int id);

  /// Merges selected rows into the oldest one (FR-08-08); returns its id,
  /// null when fewer than two rows exist.
  Future<int?> mergeRows(List<int> ids);

  /// Undoes a merge: re-reads source [sourceId] of [transactionId] into its
  /// own row (FR-07-13). Needs two or more sources and a readable text; the
  /// parent keeps balances only its remaining sources state. Returns the new
  /// row id, or null when nothing could be split.
  Future<int?> splitSource(int transactionId, int sourceId);

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
    String? usage,
  });

  /// Flagged rows awaiting a decision (FR-08-19).
  Stream<int> watchReviewCount();
  Stream<List<ReviewPair>> watchReviewPairs();
}
