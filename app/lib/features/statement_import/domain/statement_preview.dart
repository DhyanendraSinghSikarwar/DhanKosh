import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:parser_core/parser_core.dart' as pc;

/// One statement row and what importing it would do (FR-05-34).
class PreviewRow {
  /// Creates a row.
  const PreviewRow({
    required this.index,
    required this.tx,
    required this.kind,
    this.existingId,
    this.reason,
  });

  /// Position in the statement; the import skips rows by this number.
  final int index;

  /// The parsed row.
  final pc.ParsedTransaction tx;

  /// New, matches an existing payment, possible duplicate, or skipped.
  final PlanKind kind;

  /// The ledger row it matches or is compared with.
  final int? existingId;

  /// Review or skip reason.
  final String? reason;
}

/// The plan for a statement before anything is written (FR-05-34): every row
/// with its verdict, checked against the ledger as it is now.
class StatementPreview {
  /// Creates a preview.
  const StatementPreview({
    required this.file,
    required this.rows,
    this.bankName,
    this.last4,
  });

  /// The picked file, imported again on confirm.
  final PickedFile file;

  /// Bank from the statement header or sender, when known.
  final String? bankName;

  /// Account digits from the statement header, when known.
  final String? last4;

  /// Rows in statement order.
  final List<PreviewRow> rows;

  /// Rows with [kind].
  int count(PlanKind kind) => rows.where((r) => r.kind == kind).length;

  /// Rows that start unticked: already imported, deleted or ignored.
  Set<int> get skippedByDefault => {
        for (final r in rows)
          if (r.kind == PlanKind.skipped) r.index,
      };
}
