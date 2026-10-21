/// Why a file could not be read at all.
enum UnsupportedReason { scanned, protectedSheet, unreadable, unknownType }

/// Outcome of importing one statement file (FR-05-01, FR-05-11, FR-05-12).
sealed class ImportResult {
  const ImportResult();
}

/// Read and applied.
class ImportDone extends ImportResult {
  /// Creates the result.
  const ImportDone({
    required this.statementId,
    required this.added,
    required this.merged,
    required this.review,
    required this.holdings,
    this.cardNotice = false,
    this.empty = false,
  });

  /// Stored statement row.
  final int statementId;

  /// Rows that became new transactions.
  final int added;

  /// Rows merged into transactions that already existed.
  final int merged;

  /// Rows sent to review.
  final int review;

  /// Holdings inserted or updated.
  final int holdings;

  /// A card bill notice was recorded.
  final bool cardNotice;

  /// Nothing useful was found.
  final bool empty;
}

/// The file was imported before.
class ImportAlreadyDone extends ImportResult {
  /// Creates the result.
  const ImportAlreadyDone(this.statementId);

  /// Existing row.
  final int statementId;
}

/// A password is needed; the row is LOCKED (FR-05-11).
class ImportLocked extends ImportResult {
  /// Creates the result.
  const ImportLocked(this.statementId);

  /// The LOCKED row.
  final int statementId;
}

/// The password given to unlock was wrong.
class ImportWrongPassword extends ImportResult {
  /// Creates the result.
  const ImportWrongPassword(this.statementId);

  /// The still LOCKED row.
  final int statementId;
}

/// The file cannot be read.
class ImportUnsupported extends ImportResult {
  /// Creates the result.
  const ImportUnsupported(this.reason);

  /// What is wrong with it.
  final UnsupportedReason reason;
}

/// The stored file is gone (unlock of a LOCKED row).
class ImportFileMissing extends ImportResult {
  /// Creates the result.
  const ImportFileMissing();
}
