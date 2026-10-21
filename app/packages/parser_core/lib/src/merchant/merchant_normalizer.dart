import 'package:parser_core/src/extract/merchant_extractor.dart';
import 'package:parser_core/src/merchant/merchant_directory.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// A cleaned display name and the category it implies.
class NormalizedMerchant {
  /// Creates a normalized merchant.
  const NormalizedMerchant(this.name, this.category);

  /// Display name, if one could be made.
  final String? name;

  /// Category.
  final Category category;
}

/// Turns "ACH D- TP ACH ZERODHA-1234567" or "swiggy.upi@axisbank" into a
/// display name and a category (FR-06-09).
abstract final class MerchantNormalizer {
  static final RegExp _segmentSplit = rx(r'\s*[/|]\s*');
  static final RegExp _hyphenSplit = rx(r'\s*-\s*');
  static final RegExp _codeLike = rx(
    r'^(?:.*\d{4,}.*|[A-Z]{4}0[A-Z0-9]{6}|[X*\d\s]+|P2[AMP]|[A-Z]{2}\d+)$',
  );
  static final RegExp _nonWord = rx("[^A-Z0-9&' ]+");
  static final RegExp _spaces = rx(r'\s+');

  static const _noisePrefix = {
    'ACH', 'NACH', 'ECS', 'TP', 'D', 'DR', 'CR', 'UPI', 'IMPS', 'NEFT',
    'RTGS', 'POS', 'VPA', 'MMT', 'BIL', 'INF', 'TO', 'FROM', 'BY', 'SI',
    'MANDATE', 'AUTOPAY', 'PAYMENT', 'TXN', 'TRF', 'TRANSFER', 'PAY', 'CMS',
    'ATD', 'ONL', 'VIN', //
  };
  static const _noiseSuffix = {
    'PVT', 'LTD', 'PRIVATE', 'LIMITED', 'LLP', 'INC', 'CO', 'UPI', 'PAYMENTS',
    'PAYMENT', //
  };
  static const _vpaNoise = {
    'UPI', 'PAY', 'PAYTM', 'RAZORPAY', 'RZP', 'BHARATPE', 'PAYU', 'CASHFREE',
    'MERCHANT', 'OKAXIS', 'OKICICI', //
  };

  /// "UBERIND13513699", "AMAZONPAY1234": letters glued to a terminal or order
  /// number.
  static final RegExp _ifsc = rxFull('[A-Z]{4}0[A-Z0-9]{6}');
  static final RegExp _nameThenId =
      rx(r'^([A-Z]{3,}?)(?:IND|INDIA|IN)?\d{4,}$');

  static final RegExp _salary = rx(r'\b(?:SALARY|SAL\s+CR|PAYROLL)\b');

  static const _keepUpper = {
    'ATM', 'IRCTC', 'LIC', 'KFC', 'HP', 'BP', 'SBI', 'HDFC', 'ICICI', 'IDFC',
    'PNB', 'AU', 'NSE', 'BSE', //
  };

  /// The display name and category of [raw] for a message of [type] on
  /// [channel]; [fullText] decides salary and refund credits.
  static NormalizedMerchant normalize(
    RawMerchant raw,
    TransactionType type,
    Channel channel,
    String fullText,
  ) {
    if (channel == Channel.atm && type == TransactionType.debit) {
      return const NormalizedMerchant('ATM', Category.cash);
    }

    final cleaned = raw.name == null ? null : clean(raw.name!);
    final name = cleaned ?? (raw.vpa == null ? null : fromVpa(raw.vpa!));
    final upper = name?.toUpperCase();
    final tokens = upper == null
        ? const <String>[]
        : upper.split(' ').where((t) => t.isNotEmpty).toList();
    final known =
        upper == null ? null : MerchantDirectory.lookup(upper, tokens);
    final display = known?.name ?? (name == null ? null : _titleCase(name));

    final Category category;
    if (type == TransactionType.transfer) {
      category = Category.transfer;
    } else if (type == TransactionType.investment) {
      category = Category.investment;
    } else if (type == TransactionType.credit) {
      final lowerFull = fullText.toLowerCase();
      if (_salary.hasMatch(fullText.toUpperCase())) {
        category = Category.salary;
      } else if (lowerFull.contains('refund') || lowerFull.contains('revers')) {
        category = Category.refund;
      } else {
        category = Category.income;
      }
    } else if (known != null) {
      category = known.category;
    } else {
      category = MerchantDirectory.categoryByKeyword(tokens) ?? Category.other;
    }
    return NormalizedMerchant(display, category);
  }

  /// The directory category for a raw merchant string, used to promote a debit
  /// to an investment.
  static Category? categoryOf(RawMerchant raw) {
    final name = (raw.name == null ? null : clean(raw.name!)) ??
        (raw.vpa == null ? null : fromVpa(raw.vpa!));
    if (name == null) return null;
    final upper = name.toUpperCase();
    return MerchantDirectory.lookup(upper, upper.split(' '))?.category;
  }

  /// Cleans a raw merchant string; null when nothing name-like is left.
  static String? clean(String raw) {
    var s = raw.toUpperCase();
    if (s.contains('@')) return fromVpa(s);
    if (!_ifsc.hasMatch(s.trim())) {
      final m = _nameThenId.firstMatch(s.trim());
      if (m != null) s = grp(m, 1);
    }
    // "NEFT/CITIN5202.../ACME CORP" and "CITIN5202...-ACME CORP": keep the
    // first segment that is a name.
    final segments = <String>[];
    for (final seg in s.split(_segmentSplit)) {
      final parts = seg.split(_hyphenSplit);
      if (parts.length > 1 && parts.any((p) => _codeLike.hasMatch(p.trim()))) {
        segments.addAll(parts);
      } else {
        segments.add(seg);
      }
    }
    String? picked;
    for (final seg in segments.map((e) => e.trim())) {
      if (seg.isNotEmpty && !_codeLike.hasMatch(seg) && !_isOnlyNoise(seg)) {
        picked = seg;
        break;
      }
    }
    if (picked == null) return null;
    s = picked.replaceAll(_nonWord, ' ');
    final words = s.trim().split(_spaces).where((w) => w.isNotEmpty).toList();
    while (words.isNotEmpty && _noisePrefix.contains(words.first)) {
      words.removeAt(0);
    }
    while (words.length > 1 && _noiseSuffix.contains(words.last)) {
      words.removeLast();
    }
    final result = words.join(' ');
    return result.length >= 2 && result.split('').any(isLetter) ? result : null;
  }

  static bool _isOnlyNoise(String seg) => seg
      .replaceAll(_nonWord, ' ')
      .trim()
      .split(_spaces)
      .every((w) => _noisePrefix.contains(w) || w.isEmpty);

  /// A display name from the local part of a UPI id; null when it has none.
  static String? fromVpa(String vpa) {
    final at = vpa.indexOf('@');
    final local = (at < 0 ? vpa : vpa.substring(0, at)).toUpperCase();
    final words = local
        .split(RegExp('[._-]'))
        .where(
          (w) =>
              w.isNotEmpty &&
              !_vpaNoise.contains(w) &&
              w.split('').any(isLetter),
        )
        .map((w) {
      var e = w.length;
      while (e > 0 && isDigit(w[e - 1])) {
        e--;
      }
      return w.substring(0, e);
    }).where((w) => w.length >= 2);
    final joined = words.join(' ');
    return joined.isEmpty ? null : joined;
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map(
        (w) => w.length <= 3 && _keepUpper.contains(w)
            ? w
            : capitalize(w.toLowerCase()),
      )
      .join(' ');
}
