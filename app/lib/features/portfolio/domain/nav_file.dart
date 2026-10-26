/// One scheme's NAV from the AMFI file (FR-16-23).
class NavQuote {
  /// Creates a quote.
  const NavQuote({
    required this.isin,
    required this.name,
    required this.nav,
    required this.dateMs,
  });

  /// ISIN the quote is filed under.
  final String isin;
  final String name;

  /// Rupees per unit (a price, not an amount).
  final double nav;

  /// Epoch ms, noon IST of the NAV date.
  final int dateMs;
}

/// Parser of the public AMFI `NAVAll.txt` (FR-16-23). Pure and total: bad
/// lines are skipped.
///
/// Lines: `Scheme Code;ISIN Payout/Growth;ISIN Reinvestment;Scheme Name;Net
/// Asset Value;Date` (date `dd-MMM-yyyy`). Header and fund-house lines have
/// no `;` and are ignored.
abstract final class NavFileParser {
  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static final _isin = RegExp(r'^IN[A-Z0-9]{10}$');

  /// Epoch ms (noon IST) of `dd-MMM-yyyy`, or null.
  static int? parseDate(String s) {
    final p = s.trim().split('-');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = _months[p[1].toLowerCase()];
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime.utc(y, m, d, 12).millisecondsSinceEpoch - 19800000;
  }

  /// Quotes by ISIN; when an ISIN repeats the newest date wins.
  static Map<String, NavQuote> parse(String text) {
    final out = <String, NavQuote>{};
    for (final line in text.split('\n')) {
      final f = line.trim().split(';');
      if (f.length < 6) continue;
      final nav = double.tryParse(f[4].trim());
      final at = parseDate(f[5]);
      if (nav == null || nav <= 0 || at == null) continue;
      for (final raw in [f[1], f[2]]) {
        final isin = raw.trim();
        if (!_isin.hasMatch(isin)) continue;
        final old = out[isin];
        if (old == null || old.dateMs < at) {
          out[isin] = NavQuote(
            isin: isin,
            name: f[3].trim(),
            nav: nav,
            dateMs: at,
          );
        }
      }
    }
    return out;
  }
}
