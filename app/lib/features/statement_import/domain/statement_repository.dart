import 'package:hisaab/features/statement_import/domain/statement.dart';

/// Statement rows (FR-05-01, FR-05-11, FR-05-19). Never writes the ledger:
/// the import use case calls `TransactionRepository.ingest` itself.
abstract interface class StatementRepository {
  /// Stores [s] unless its key exists (FR-05-01): an existing LOCKED row
  /// yields [StatementRetryLocked], any other [StatementAlreadyImported].
  Future<StatementInsert> insert(NewStatement s);

  /// True when a statement with [key] exists (e.g. `file:<sha>`).
  Future<bool> exists(String key);

  /// Row with [key], or null.
  Future<Statement?> byKey(String key);

  /// Row with [id], or null.
  Future<Statement?> byId(int id);

  /// Newest first by `receivedAt`, then id.
  Stream<List<Statement>> watchAll();

  /// Rows needing a password, newest first.
  Future<List<Statement>> locked();

  /// Count of LOCKED rows (red section badge).
  Stream<int> watchLockedCount();

  /// Stores the read result of [id] (status, kind, counts, totals, bank).
  /// A LOCKED row moves to PARSED or EMPTY on unlock (FR-05-12).
  Future<void> markProcessed(
    int id, {
    required StatementStatus status,
    required int at,
    StatementKind? kind,
    String? bankName,
    String? last4,
    int? transactionCount,
    int? holdingCount,
    StatementTotals? totals,
    String? filePath,
  });

  /// Marks [id] as needing a password, keeping [emailText] (capped at 4000).
  Future<void> markLocked(int id, {required int at, String? emailText});

  /// Removes the row (FR-05-19) and returns its stored file path so the
  /// caller can delete the file; null when there is none.
  Future<String?> delete(int id);
}
