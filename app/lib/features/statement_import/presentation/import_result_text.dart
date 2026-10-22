import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';

/// Short snackbar text for an import outcome (FR-05-01, FR-05-11).
String importResultText(ImportResult r) => switch (r) {
      ImportDone() => _done(r),
      ImportAlreadyDone() => 'Already imported.',
      ImportLocked() => 'Locked. Enter the password.',
      ImportWrongPassword() => 'Wrong password.',
      ImportFileMissing() => 'File is missing. Import it again.',
      ImportUnsupported(:final reason) => switch (reason) {
          UnsupportedReason.scanned => 'Scanned PDFs are not supported.',
          UnsupportedReason.protectedSheet =>
            'Protected spreadsheet. Remove the password and retry.',
          UnsupportedReason.unreadable => 'Cannot read this file.',
          UnsupportedReason.unknownType => 'Use a PDF, XLSX or CSV file.',
          UnsupportedReason.xls => 'Old .xls is not supported. Save as .xlsx.',
          UnsupportedReason.tooLarge => 'File is too large.',
        },
    };

String _done(ImportDone d) {
  if (d.empty) return 'Nothing found in this statement.';
  final parts = [
    if (d.added > 0) '${d.added} added',
    if (d.merged > 0) '${d.merged} merged',
    if (d.review > 0) '${d.review} to review',
    if (d.holdings > 0) '${d.holdings} holdings updated',
    if (d.cardNotice) 'card bill saved',
    if (d.deposits > 0) '${d.deposits} deposits updated',
    if (d.accountEffect.applied) _effect(d.accountEffect),
    if (d.mismatch != null) 'holdings differ from statement totals',
  ];
  return parts.isEmpty ? 'Imported.' : '${parts.join(', ')}.';
}

String _effect(AccountEffect e) => switch (e.kind) {
      AccountEffectKind.availableLimit => 'card limit updated',
      AccountEffectKind.closingBalance => 'balance updated',
      AccountEffectKind.none => '',
    };
