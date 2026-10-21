import 'package:hisaab/features/statement_import/domain/statement_repository.dart'
    show StatementRepository;

/// Lifecycle of a statement row (memory 05 section 10): LOCKED -> PARSED or
/// EMPTY on unlock; UNREADABLE is terminal.
enum StatementStatus { parsed, locked, empty, unreadable }

/// What the statement turned out to be. Card bill/payment/override rows live
/// in the credit_cards tables, not here.
enum StatementKind { creditCard, bank, investment, other, protected }

/// Where the file came from.
enum StatementSource { email, file, sms, manual }

/// Totals read from a statement (FR-05-06). Money in paise, days as epoch
/// days.
class StatementTotals {
  /// Creates totals; every field is optional.
  const StatementTotals({
    this.totalDueMinor,
    this.minDueMinor,
    this.dueEpochDay,
    this.creditLimitMinor,
    this.statementEpochDay,
    this.openingMinor,
    this.closingMinor,
    this.debitsMinor,
    this.creditsMinor,
    this.availableMinor,
  });

  final int? totalDueMinor;
  final int? minDueMinor;
  final int? dueEpochDay;
  final int? creditLimitMinor;
  final int? statementEpochDay;
  final int? openingMinor;
  final int? closingMinor;
  final int? debitsMinor;
  final int? creditsMinor;
  final int? availableMinor;
}

/// A statement about to be stored (`StatementMeta` of memory 05).
class NewStatement {
  /// Creates a statement in [status] (default: parsed).
  const NewStatement({
    required this.key,
    required this.source,
    required this.sender,
    required this.fileName,
    required this.receivedAt,
    required this.processedAt,
    this.status = StatementStatus.parsed,
    this.subject,
    this.filePath,
    this.bankName,
    this.last4,
    this.kind,
    this.transactionCount = 0,
    this.holdingCount = 0,
    this.totals = const StatementTotals(),
    this.emailText,
  });

  /// `file:<sha>` or `<msgId>#pdf<i>`.
  final String key;
  final StatementSource source;
  final String sender;
  final String fileName;
  final int receivedAt;
  final int processedAt;
  final StatementStatus status;
  final String? subject;
  final String? filePath;
  final String? bankName;
  final String? last4;
  final StatementKind? kind;
  final int transactionCount;
  final int holdingCount;
  final StatementTotals totals;

  /// Kept to [emailTextCap] characters.
  final String? emailText;
}

/// Longest email text kept per statement (FR-05-11).
const emailTextCap = 4000;

/// A stored statement.
class Statement {
  /// Creates a statement.
  const Statement({
    required this.id,
    required this.key,
    required this.source,
    required this.sender,
    required this.fileName,
    required this.receivedAt,
    required this.status,
    required this.processedAt,
    required this.transactionCount,
    required this.holdingCount,
    required this.totals,
    this.subject,
    this.filePath,
    this.bankName,
    this.last4,
    this.kind,
    this.emailText,
  });

  final int id;
  final String key;
  final StatementSource source;
  final String sender;
  final String fileName;
  final int receivedAt;
  final StatementStatus status;
  final int processedAt;
  final int transactionCount;
  final int holdingCount;
  final StatementTotals totals;
  final String? subject;
  final String? filePath;
  final String? bankName;
  final String? last4;
  final StatementKind? kind;
  final String? emailText;

  /// Needs a password from the user (FR-05-11).
  bool get isLocked => status == StatementStatus.locked;
}

/// Outcome of [StatementRepository.insert] (FR-05-01).
sealed class StatementInsert {
  const StatementInsert();
}

/// A new row was stored.
class StatementInserted extends StatementInsert {
  /// Creates the result.
  const StatementInserted(this.statement);
  final Statement statement;
}

/// The key exists and is not locked: "Already imported."
class StatementAlreadyImported extends StatementInsert {
  /// Creates the result.
  const StatementAlreadyImported(this.statement);
  final Statement statement;
}

/// The key exists but is LOCKED, so the caller retries opening it.
class StatementRetryLocked extends StatementInsert {
  /// Creates the result.
  const StatementRetryLocked(this.statement);
  final Statement statement;
}
