import 'package:hisaab/features/transactions_ledger/domain/add_draft.dart';
import 'package:parser_core/parser_core.dart';

/// Reads text another app shared into DhanKosh (a UPI receipt, a forwarded
/// bank message, a quick note such as "450 swiggy") into a pre-filled Add form
/// (FR-08-27). Nothing is saved until the user taps Save.
abstract final class SharedTextDraft {
  /// Longest text kept; the native side caps it too.
  static const maxChars = 1000;

  /// A short note is "just a number and a word".
  static const noteChars = 40;

  // A bare number: 1-6 digits, optional 1-2 decimals; not part of a longer
  // number, a date (03/10), a range (10-12) or an account mask (XX1234).
  static final RegExp _bare = RegExp(
    r'(?<![\w/.,\-])(\d{1,6})(?:\.(\d{1,2}))?(?![\d/\-]|[.,]\d)',
  );
  static final RegExp _letters = RegExp('[A-Za-z]');

  /// The form for [raw], or null when there is no text. [now] is "today".
  static AddDraft? of(String? raw, {required DateTime now}) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    final kept = text.length > maxChars ? text.substring(0, maxChars) : text;

    // A bank message or receipt: amount, direction, payee, reference, date.
    final d = const FreeTextParser().draft(kept, now.millisecondsSinceEpoch);
    final minor = d?.amountMinor;
    if (d != null && minor != null && minor > 0) {
      // Never put a foreign amount in the rupee field.
      final inr = d.currency == 'INR';
      return AddDraft(
        heading: 'Add from shared text',
        sourceText: kept,
        amountMinor: inr ? minor : null,
        type: d.type == TransactionType.credit
            ? TransactionType.credit
            : (d.type == null ? null : TransactionType.debit),
        merchant: d.merchant,
        reference: d.reference,
        category: d.category,
        when: DateTime.fromMillisecondsSinceEpoch(d.time),
        note: kept,
      );
    }

    // A note: "450 swiggy", "chai 80.5". Only when short, so a long sentence
    // with a stray number is never read as an amount.
    if (kept.length <= noteChars) {
      final m = _bare.firstMatch(kept);
      if (m != null) {
        final number =
            m.group(2) == null ? m.group(1)! : '${m.group(1)}.${m.group(2)}';
        final money = Money.parse(number);
        if (money != null && money.minor > 0) {
          final rest = kept.replaceRange(m.start, m.end, ' ');
          return AddDraft(
            heading: 'Add from shared text',
            sourceText: kept,
            amountMinor: money.minor,
            merchant: _payee(rest),
            note: kept,
          );
        }
      }
    }
    return AddDraft(
      heading: 'Add from shared text',
      sourceText: kept,
      note: kept,
    );
  }

  /// The words around the number as a payee, when they are plainly a name.
  static String? _payee(String rest) {
    final words = rest
        .replaceAll(RegExp(r'[^A-Za-z0-9&\x27 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final text = words.join(' ');
    if (text.isEmpty || text.length > 30 || !_letters.hasMatch(text)) {
      return null;
    }
    return [
      for (final w in words)
        if (w.length == 1)
          w.toUpperCase()
        else
          '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
    ].join(' ');
  }
}
