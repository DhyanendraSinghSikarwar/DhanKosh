import 'package:parser_core/parser_core.dart';

/// One message to put in the ledger (FR-07-07).
class IngestItem {
  const IngestItem({
    required this.parsed,
    required this.sourceMessageId,
    this.rawText,
    this.subject,
    this.accountId,
    this.note,
    this.phoneLast4s = const {},
  });

  final ParsedTransaction parsed;

  /// Id of the message in its source (SMS id, mail uid, `manual:<uuid>`...).
  final String sourceMessageId;
  final String? rawText;
  final String? subject;

  /// Forces the account (manual entries); skips `ensureAccount`.
  final int? accountId;
  final String? note;
  final Set<String> phoneLast4s;
}

enum IngestOutcome { inserted, merged, flagged, skipped }

class IngestResult {
  const IngestResult(this.outcome, {this.transactionId, this.reason});
  final IngestOutcome outcome;

  /// Row inserted, merged into, or flagged; null when skipped.
  final int? transactionId;

  /// Review reason or skip reason (`already_processed`, `deleted`).
  final String? reason;
}

/// Counts for "a new, b merged, c to review" (FR-07-16).
class IngestReport {
  const IngestReport(this.results);
  final List<IngestResult> results;

  int _n(IngestOutcome o) => results.where((r) => r.outcome == o).length;
  int get inserted => _n(IngestOutcome.inserted);
  int get merged => _n(IngestOutcome.merged);
  int get flagged => _n(IngestOutcome.flagged);
  int get skipped => _n(IngestOutcome.skipped);
}
