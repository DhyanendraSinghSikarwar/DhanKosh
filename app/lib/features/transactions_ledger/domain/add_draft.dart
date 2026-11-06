import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:parser_core/parser_core.dart';

/// What the Add form holds when the user taps Save.
class AddFormValues {
  /// Creates form values.
  const AddFormValues({
    required this.amountMinor,
    required this.type,
    required this.timestamp,
    this.accountId,
    this.merchant,
    this.category = Category.other,
    this.reference,
    this.note,
  });

  /// Amount in paise.
  final int amountMinor;

  /// Spent, received or transfer.
  final TransactionType type;

  /// Time, epoch ms.
  final int timestamp;

  /// Chosen account.
  final int? accountId;

  /// Payee.
  final String? merchant;

  /// Category.
  final Category category;

  /// Reference number.
  final String? reference;

  /// Note.
  final String? note;
}

/// A form to open pre-filled: a reviewed message, shared text, a quick entry
/// (F-38, FR-38-11, FR-38-12). Every field is optional.
class AddDraft {
  /// Creates a draft.
  const AddDraft({
    this.amountMinor,
    this.type,
    this.merchant,
    this.reference,
    this.category,
    this.accountId,
    this.when,
    this.note,
    this.heading,
    this.sourceText,
    this.onConfirm,
  });

  /// Amount in paise.
  final int? amountMinor;

  /// Spent or received.
  final TransactionType? type;

  /// Payee.
  final String? merchant;

  /// Reference number.
  final String? reference;

  /// Category.
  final Category? category;

  /// Account to select.
  final int? accountId;

  /// Time.
  final DateTime? when;

  /// Note.
  final String? note;

  /// Replaces the screen title.
  final String? heading;

  /// The message the draft was read from, shown above the form.
  final String? sourceText;

  /// When set, Save hands the form to this instead of adding a manual entry,
  /// so the caller keeps the message's identity (FR-38-11).
  final Future<IngestResult> Function(AddFormValues values)? onConfirm;
}
