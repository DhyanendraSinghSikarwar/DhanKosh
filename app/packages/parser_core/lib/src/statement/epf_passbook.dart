import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/statement/investment_parser.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// An EPFO member passbook (PDF from the EPFO portal or UMANG): the member id
/// and the "Closing Balance" row, whose last three figures are the employee
/// share, the employer share and the pension contribution. The value is their
/// sum; the amount invested is that less the interest the passbook credits
/// ("Int. Updated upto 31/03/2026"). One holding per member id:
/// `EPF:<member id without separators>`, the same key the EPFO SMS gives.
abstract final class EpfPassbook {
  static final RegExp _isEpf =
      rx(r"employees'?\s*provident\s+fund|\bEPFO\b|member\s+passbook");
  static final RegExp _member = rx(
    r'\bmember\s+id(?:\s*/\s*name)?\s*[:\-]?\s*([A-Z]{2}\s*/?\s*[A-Z]{3}[A-Z0-9/\s]{8,30}?\d{3,})',
  );
  static final RegExp _closing = rx(r'\bclosing\s+balance\b');
  static final RegExp _interest = rx(r'\bint(?:erest)?\.?\s+updated\b');
  static final RegExp _opening = rx(r'\bOB\b|opening\s+balance');
  static final RegExp _date = RegExp(
    r'\b\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}\b|\b\d{1,2}[\s-][A-Za-z]{3}[\s-]\d{2,4}\b',
  );
  static final RegExp _monthCode = RegExp(r'\b(?:0[1-9]|1[0-2])\d{4}\b');
  static final RegExp _number = RegExp(
    r'(?<![\w.,/])\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?(?![\w,/])|(?<![\w.,/])\d+(?:\.\d{1,2})?(?![\w.,/%])',
  );

  /// Whether [lines] are an EPFO member passbook.
  static bool isEpf(List<String> lines) {
    final head = lines.take(40).join(' ');
    return _isEpf.hasMatch(head) && _member.hasMatch(head);
  }

  /// The EPF holding, or empty.
  static List<HoldingSnapshot> read(List<String> lines, int asOf) {
    if (!isEpf(lines)) return const [];
    String? raw;
    for (final l in lines.take(40)) {
      final m = _member.firstMatch(l);
      if (m != null) {
        raw = grp(m, 1);
        break;
      }
    }
    if (raw == null) return const [];
    final member = InvestmentParser.epfMemberKey(raw);
    int? closing;
    var interest = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_closing.hasMatch(line)) {
        // The figures can wrap onto the next line.
        var s = _shares(line);
        if (s.isEmpty) s = _shares(i + 1 < lines.length ? lines[i + 1] : '');
        if (s.isNotEmpty) closing = s.fold<int>(0, (a, b) => a + b);
      } else if (_interest.hasMatch(line) && !_opening.hasMatch(line)) {
        interest += _shares(line).fold<int>(0, (a, b) => a + b);
      }
    }
    if (closing == null || closing <= 0) return const [];
    final c = closing;
    final inv = c - interest;
    final invested = interest > 0 && inv > 0 ? inv : null;
    return [
      HoldingSnapshot(
        kind: HoldingKind.epf,
        name: 'EPF ••${takeLast(member, 4)}',
        identifier: 'EPF:$member',
        units: null,
        valueMinor: c,
        investedMinor: invested,
        asOf: asOf,
      ),
    ];
  }

  /// The employee, employer and pension figures at the end of a row, in paise
  /// (fewer when the row has fewer).
  static List<int> _shares(String line) {
    final plain = line.replaceAll(_date, ' ').replaceAll(_monthCode, ' ');
    final nums = _number.allMatches(plain).map((m) => m.group(0)!).toList();
    if (nums.isEmpty) return const [];
    final last = nums.length > 3 ? nums.sublist(nums.length - 3) : nums;
    return [
      for (final n in last)
        if (Money.parseSigned(n) case final v?) v,
    ];
  }
}
