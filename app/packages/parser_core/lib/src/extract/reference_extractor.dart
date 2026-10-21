import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// UPI RRN, IMPS/NEFT UTR, or bank transaction id. Upper-cased, alphanumeric
/// only (FR-06-07).
abstract final class ReferenceExtractor {
  static final _slashed = Guarded(
    r'\b(?:UPI|IMPS|NEFT|RTGS)/(?:[A-Z0-9]{2,4}/)?([A-Z0-9]{9,22})/',
    ['upi/', 'imps/', 'neft/', 'rtgs/'],
  );
  static final _labelled = Guarded(
    r'\b(?:UPI\s*transaction\s*reference\s*(?:number|no\.?)|(?:UPI|IMPS|NEFT|RTGS)(?:\s*Ref(?:erence|\.)?)?(?:\s*(?:No|Number|ID)\.?)?|'
    r'RRN|UTR(?:\s*No\.?)?|Refno|Ref(?:erence)?(?:\s*(?:No|Number|ID)\.?|\s*#)?|'
    r'(?:Txn|Trxn|Transaction)\s*(?:ID|No\.?|Number|Ref(?:erence)?(?:\s*No\.?)?))'
    r'\s*(?:is\s*)?[:.\-#]?\s*\(?\s*([A-Z0-9]{6,22})\b',
    [
      'upi', 'imps', 'neft', 'rtgs', 'rrn', 'utr', 'ref', 'txn', 'trxn',
      'transaction', //
    ],
  );
  static const _minDigits = 5;

  /// The reference in [text], upper-cased, or null.
  static String? extract(String text, [String? lowerText]) {
    final lower = lowerText ?? text.toLowerCase();
    final slashed = _slashed.find(text, lower);
    if (slashed != null) return grp(slashed, 1).toUpperCase();
    var m = _labelled.find(text, lower);
    while (m != null) {
      final ref = grp(m, 1);
      // "UPI transaction" also fits the pattern; a real reference is mostly
      // digits. Retry from the next character, so "UPI transaction ID 5268..."
      // still finds the "transaction ID" label inside the miss.
      final digits = ref.split('').where(isDigit).length;
      if (digits >= _minDigits) return ref.toUpperCase();
      m = findFrom(_labelled.regex, text, m.start + 1);
    }
    return null;
  }

  /// Letters and digits only, upper-cased, at least six characters.
  static String? normalize(String? ref) {
    if (ref == null) return null;
    final r = lettersAndDigits(ref).toUpperCase();
    return r.length >= 6 ? r : null;
  }
}
