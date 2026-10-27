import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/ocr_port.dart';
import 'package:parser_core/parser_core.dart';

/// Result of reading a screenshot (FR-08-12): a [draft] to review on the Add
/// screen, or none when no amount was found. Never saved by itself.
class ScreenshotFill {
  /// Creates a result.
  const ScreenshotFill({this.draft, this.accountId, this.text = ''});

  /// What could be read, or null when no amount was found.
  final TransactionDraft? draft;

  /// Account guessed from the last digits, or null.
  final int? accountId;

  /// The recognised text (kept as source text when saved).
  final String text;

  /// True when an amount was found.
  bool get found => draft != null;
}

/// Picks, recognises and parses a screenshot into a draft (FR-08-12).
class ScreenshotFillService {
  /// Creates the service. [now] is epoch ms.
  ScreenshotFillService({
    required TextRecognizerPort recognizer,
    int Function()? now,
  })  : _recognizer = recognizer,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final TextRecognizerPort _recognizer;
  final int Function() _now;

  /// Reads the image at [path]; [accounts] are the visible accounts.
  Future<ScreenshotFill> read(String path, List<Account> accounts) async =>
      fromText(await _recognizer.recognize(path), accounts);

  /// Parses recognised [text] (also the unit-test entry point).
  ScreenshotFill fromText(String text, List<Account> accounts) {
    final draft = const FreeTextParser().draft(text, _now());
    if (draft == null) return ScreenshotFill(text: text);
    return ScreenshotFill(
      draft: draft,
      accountId: guessAccount(draft, accounts),
      text: text,
    );
  }

  /// Account whose last digits end with the draft's, and whose bank matches
  /// when the draft names one; null when none or ambiguous.
  static int? guessAccount(TransactionDraft draft, List<Account> accounts) {
    final last4 = draft.last4;
    if (last4 == null || last4.isEmpty) return null;
    final bank = draft.bankName?.toLowerCase();
    final hits = accounts.where((a) {
      if (a.last4.isEmpty || !a.last4.endsWith(last4)) return false;
      return bank == null || a.bankName.toLowerCase().contains(bank);
    }).toList();
    return hits.length == 1 ? hits.first.id : null;
  }
}
