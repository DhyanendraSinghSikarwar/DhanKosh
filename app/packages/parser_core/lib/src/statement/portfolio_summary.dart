// Parity with the Kotlin string concatenation of long regexes.
// ignore_for_file: use_string_buffers
import 'package:parser_core/src/bank/deposits.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/civil.dart';

class _Cls {
  _Cls(this.key, this.kind, this.name, String label) : label = rx(label);
  final String key;
  final HoldingKind kind;
  final String name;
  final RegExp label;
}

/// INDmoney's portfolio summary email: invested and current value per asset
/// class ("Mutual Funds Rs 1,20,000 Rs 1,35,400", "US Stocks: Invested
/// Rs 50,000 . Current Rs 58,200"). Each class becomes one aggregate holding,
/// `AGG:INDMONEY:<class>`, which stands in until the funds or stocks are known
/// one by one (from a CAS or a holdings statement); the holdings store drops
/// the aggregate then, so nothing is counted twice (FR-05-25).
abstract final class PortfolioSummary {
  /// Identifier prefix of an aggregate holding: a whole asset class at one
  /// platform.
  static const aggregate = 'AGG:';

  static final List<_Cls> _classes = [
    _Cls(
      'US',
      HoldingKind.stock,
      'US stocks (INDmoney)',
      r'^\W*(?:US\s+stocks?|US\s+equit(?:y|ies)|global\s+stocks?)\b',
    ),
    _Cls(
      'MF',
      HoldingKind.mutualFund,
      'Mutual funds (INDmoney)',
      r'^\W*(?:mutual\s+funds?|MFs?)\b',
    ),
    _Cls(
      'STOCKS',
      HoldingKind.stock,
      'Indian stocks (INDmoney)',
      r'^\W*(?:indian\s+stocks?|IND\s+stocks?|stocks?|equit(?:y|ies)|shares)\b',
    ),
  ];
  static final RegExp _isSummary = rx(
    r'\bportfolio\b.{0,40}\b(?:summary|update|snapshot|report|overview)\b|\b(?:weekly|monthly|daily)\s+(?:portfolio|wealth|net\s*worth)\b|\bnet\s*worth\s+(?:summary|update|report)\b',
  );
  static final RegExp _indmoney = rx('indmoney');
  static final RegExp _amount =
      rx(r'(?:₹|\bRs\.?|\bINR)\s*([\d,]+(?:\.\d{1,2})?)');
  static final RegExp _invested = rx(r'\binvested\b|\binvestment\b|\bcost\b');
  static final RegExp _current =
      rx(r'\bcurrent\b|\bvalue\b|\bworth\b|\bmarket\b');
  static final RegExp _asOn = rx(
    r'\bas\s+(?:on|of)\s*:?\s*(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{1,2}(?:st|nd|rd|th)?[\s-][A-Za-z]{3,9}[\s,-]+\d{2,4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})',
  );

  /// The aggregate holdings in an INDmoney summary email; empty for any other
  /// email.
  static List<HoldingSnapshot> parse(
    String text,
    String? subject,
    String sender,
    int receivedAt, {
    ParserConfig config = const ParserConfig(),
  }) {
    final head =
        '${subject ?? ''} ${text.length > 1500 ? text.substring(0, 1500) : text}';
    if (!_indmoney.hasMatch('$sender $head') || !_isSummary.hasMatch(head)) {
      return const [];
    }
    final lines = text
        .split(RegExp(r'\r\n|\n|\r'))
        .map((l) => l.replaceAll(' ', ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final received = civilDateOf(receivedAt, config.utcOffset);
    var asOf = receivedAt;
    final am = _asOn.firstMatch(head);
    if (am != null) {
      final d = DepositParser.parseDate(am.group(1)!);
      if (d != null &&
          !d.isAfter(received.plusDays(1)) &&
          !d.isBefore(received.minusDays(31))) {
        asOf = epochOf(d, const CivilTime(12, 0), config.utcOffset);
      }
    }
    // A table header ("Asset  Current Value  Invested") says which figure
    // comes first.
    var currentFirst = false;
    for (final l in lines) {
      if (_invested.hasMatch(l) &&
          _current.hasMatch(l) &&
          _amount.firstMatch(l) == null) {
        currentFirst =
            _current.firstMatch(l)!.start < _invested.firstMatch(l)!.start;
        break;
      }
    }
    final out = <String, HoldingSnapshot>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      _Cls? cls;
      for (final c in _classes) {
        if (c.label.hasMatch(line)) {
          cls = c;
          break;
        }
      }
      if (cls == null || out.containsKey(cls.key)) continue;
      // The figures on the label's line, or on the next few lines (an HTML
      // table read as text).
      var block = line;
      var j = i + 1;
      while (_amount.allMatches(block).length < 2 &&
          j < lines.length &&
          j <= i + 4 &&
          !_classes.any((c) => c.label.hasMatch(lines[j]))) {
        block += ' ${lines[j]}';
        j++;
      }
      final f = _figures(block, currentFirst: currentFirst);
      if (f == null) continue;
      out[cls.key] = HoldingSnapshot(
        kind: cls.kind,
        name: cls.name,
        identifier: '${aggregate}INDMONEY:${cls.key}',
        units: null,
        valueMinor: f.$2,
        investedMinor: f.$1,
        asOf: asOf,
      );
    }
    return out.values.toList();
  }

  /// Invested and current value in [block]: by their labels when it has them,
  /// else by position.
  static (int?, int)? _figures(String block, {required bool currentFirst}) {
    final amounts = <(int, int)>[
      for (final m in _amount.allMatches(block))
        if (Money.parse(m.group(1)!)?.minor case final v?) (m.start, v),
    ];
    if (amounts.isEmpty) return null;
    int? labelled(RegExp label) {
      for (final l in label.allMatches(block)) {
        for (final a in amounts) {
          if (a.$1 > l.end - 1) return a.$2;
        }
      }
      return null;
    }

    final inv = labelled(_invested);
    final cur = labelled(_current);
    if (inv != null && cur != null && inv != cur) return (inv, cur);
    if (amounts.length == 1) return (null, amounts[0].$2);
    final a = amounts[0].$2;
    final b = amounts[1].$2;
    return currentFirst ? (b, a) : (a, b);
  }
}
