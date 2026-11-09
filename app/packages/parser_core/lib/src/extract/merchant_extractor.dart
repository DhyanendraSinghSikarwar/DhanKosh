import 'package:parser_core/src/extract/generic_phrases.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// The counterparty as written in the message. `MerchantNormalizer` turns it
/// into a display name.
class RawMerchant {
  /// Creates a raw merchant.
  const RawMerchant(this.name, this.vpa);

  /// Name as written, if any.
  final String? name;

  /// UPI id, if any.
  final String? vpa;

  @override
  bool operator ==(Object other) =>
      other is RawMerchant && other.name == name && other.vpa == vpa;

  @override
  int get hashCode => Object.hash(name, vpa);

  @override
  String toString() => 'RawMerchant($name, $vpa)';
}

/// Finds the payee or payer in a message with ordered patterns (FR-06-07).
abstract final class MerchantExtractor {
  static const _body = r"[A-Z0-9][A-Z0-9 &'*_\-/@.]{0,50}?";
  static const _end =
      r'(?=\s+(?:on|dated|ref|refno|rrn|utr|upi|imps|neft|via|for|using|with|avl|avbl|bal|not|if|from|at|thru|through|and|txn|info|call|is|has|was)\b|\s*[.,;:(|!]|\s+-|$)';
  static const _title = r'(?:(?:mr|mrs|ms|miss|dr|shri|smt|sri|m/s)\.?\s+)?';
  static const _notAName =
      r'(?!(?:your|you|the|a/c|ac|acct|account|card|mobile|vpa|beneficiary|neft|imps|upi|rtgs|inr|usd|a|an|block|dispute|report|ur|u|inform|avoid|know)\b)';

  static final _slashed = Guarded(
    r'\b(?:UPI|IMPS|NEFT|RTGS)/(?:[A-Z0-9]{2,4}/)?[A-Z0-9]{9,22}/([^/]+?)(?=/|\s+(?:Not|Avl|Axis|If)\b|\.(?:\s|$)|$)',
    ['upi/', 'imps/', 'neft/', 'rtgs/'],
  );
  static final _vpaWithName = Guarded(
    r'\b(?:to|from|by)\s+VPA\s+([\w.\-]+@[\w.\-]+?)(?:\s+(' +
        _body +
        '))?' +
        _end,
    ['vpa'],
  );
  static final _beneficiary = Guarded(
    r'\b(?:beneficiary(?:\s+name)?|merchant(?:\s+name)?|payee(?:\s+name)?|sender(?:\s+name)?|remitter)(?:\s*[:\-]\s*|\s+)' +
        _notAName +
        '(' +
        _body +
        ')' +
        _end,
    ['beneficiary', 'merchant', 'payee', 'sender', 'remitter'],
  );
  static final _at = Guarded(
    r'\bat\s+' + _notAName + '(' + _body + ')' + _end,
    ['at '],
  );
  static final _vpa = Guarded(
    r'\b([a-z0-9][\w.\-]{1,}@[a-z][a-z0-9]{1,20})\b(?!\.[a-z])',
    ['@'],
  );
  static final _to = Guarded(
    r'\b(?:trf\s+to|transferred\s+to|paid\s+to|sent\s+to|to)\s+' +
        _notAName +
        _title +
        '(' +
        _body +
        ')' +
        _end,
    ['to '],
  );
  static final _from = Guarded(
    r'\b(?:from|by)\s+' + _notAName + _title + '(' + _body + ')' + _end,
    ['from ', 'by '],
  );
  static final _towards = Guarded(
    r'\btowards\s+' + _notAName + '(' + _body + ')' + _end,
    ['towards'],
  );
  static final _info = Guarded(
    r'\bInfo\s*[:\-]\s*(.{2,60}?)(?=\.\s|\s+Avl\b|\s+The\b|$)',
    ['info'],
  );
  static final _ach = Guarded(
    r"\b(?:ACH|NACH|ECS)(?:[\s\-]*(?:DR|D|CR))?[\s\-/]+([A-Z][A-Z0-9 &.'\-]+?)(?=/|-\d|\.(?:\s|$)|\s+Avl\b|$)",
    ['ach', 'ecs'],
  );

  /// "... 05-10-26 23:16:18 IST. First Cry. Avl Limit": a card alert that puts
  /// the merchant on its own line after the date.
  static final RegExp _afterDate = rx(
    r'(?:\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\b20\d{2}-\d{2}-\d{2})(?:[\sT:]+\d{1,2}:\d{2}(?::\d{2})?)?(?:\s*(?:IST|[ap]m))?\.\s+'
    r'(?!(?:avl|avbl|available|not|sms|if|call|limit|bal|upi|ref|rrn|utr|imps|neft|txn|transaction|thank|to|for|your|dear|info|total|use|click|visit|report|dispute)\b)'
    r"([A-Za-z][A-Za-z0-9 &'*_\-/@]{1,50}?)(?=\.(?:\s|$)|$)",
  );

  /// "spent using ICICI Bank Card XX4006 on 05-Oct-26 on SWIGGY."
  static final _dateOn = Guarded(
    r'\b\d{1,2}[-/ ](?:\d{1,2}|[A-Za-z]{3})[-/ ]\d{2,4}\s+on\s+' +
        _notAName +
        '(' +
        _body +
        ')' +
        _end,
    [' on '],
  );
  static final RegExp _longDigits = rx(r'\d{5,}');
  static final RegExp _hasLetter = rx('[A-Za-z]{2,}');

  /// The raw counterparty of [text] for a message of [type].
  static RawMerchant extract(
    String text,
    TransactionType type, [
    String? lowerText,
  ]) {
    final lower = lowerText ?? text.toLowerCase();
    final slashed = _slashed.find(text, lower);
    if (slashed != null) {
      final v = _valid(slashed.group(1));
      if (v != null) return RawMerchant(v, null);
    }
    final withName = _vpaWithName.find(text, lower);
    if (withName != null) {
      return RawMerchant(_valid(withName.group(2)), grp(withName, 1));
    }
    final bene = _beneficiary.find(text, lower);
    if (bene != null) {
      final v = _valid(bene.group(1));
      if (v != null) return RawMerchant(v, null);
    }

    final ordered = type == TransactionType.credit
        ? [_from, _info, _vpa, _ach]
        : [_at, _vpa, _info, _ach, _to, _towards];
    for (final g in ordered) {
      for (final m in g.findAll(text, lower)) {
        final candidate = _valid(m.group(1));
        if (candidate == null) continue;
        return identical(g, _vpa)
            ? RawMerchant(null, _cleanVpa(candidate))
            : RawMerchant(candidate, _vpaIn(candidate));
      }
    }
    if (type != TransactionType.credit) {
      for (final m in _dateOn.findAll(text, lower)) {
        final v = _valid(m.group(1));
        if (v != null) return RawMerchant(v, null);
      }
    }
    final after = findFrom(_afterDate, text);
    if (after != null) {
      final v = grp(after, 1);
      if (!_longDigits.hasMatch(v)) {
        final valid = _valid(v);
        if (valid != null) return RawMerchant(valid, null);
      }
    }
    return const RawMerchant(null, null);
  }

  static String? _vpaIn(String s) {
    final m = findFrom(_vpa.regex, s);
    final v = m?.group(1);
    return v == null ? null : _cleanVpa(v);
  }

  static final RegExp _refPrefix = rx(r'^(?:upi|imps|neft|rtgs)[-/]\d{6,}[-/]');
  static final RegExp _digitRun = rx(r'\d{6,}');

  /// A UPI id glued to what the bank wrote before it
  /// (`UPI-612345678901-SHOP-shop@icici`): keep the id itself, the part after
  /// the last separator that follows a reference or a payee name.
  static String _cleanVpa(String v) {
    var s = v.replaceFirst(_refPrefix, '');
    final at = s.indexOf('@');
    if (at < 0) return s;
    final local = s.substring(0, at);
    if (local.contains('-') &&
        (_digitRun.hasMatch(local) || _refPrefix.hasMatch(v))) {
      s = '${local.substring(local.lastIndexOf('-') + 1)}${s.substring(at)}';
    } else if (local.contains('-')) {
      // "SHOP-shop@icici": a name then the id; the id has no capitals.
      final parts = local.split('-');
      if (parts.length > 1 && parts.first == parts.first.toUpperCase()) {
        s = '${parts.last}${s.substring(at)}';
      }
    }
    return s;
  }

  static String? _valid(String? s) {
    if (s == null) return null;
    final t = trimChars(trimChars(s, ' \t\n\r'), '-/. ');
    if (t.length < 2 ||
        !_hasLetter.hasMatch(t) ||
        GenericPhrases.isGeneric(t)) {
      return null;
    }
    return t;
  }
}
