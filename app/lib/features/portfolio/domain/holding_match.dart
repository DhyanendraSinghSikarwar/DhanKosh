import 'package:hisaab/features/portfolio/domain/asset_class.dart';

/// Identity of a holding for matching (memory 16 section 3.10).
class HoldingKey {
  /// Creates a key.
  const HoldingKey(this.kind, this.identifier, this.name);

  final HoldingKind kind;
  final String identifier;
  final String name;
}

/// When two holdings are one investment (FR-16-17), ported from
/// `HoldingMatch.kt`.
abstract final class HoldingMatch {
  static final _isin = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$');
  static const epfDefault = 'EPF:default';

  static const _stop = {
    'direct', 'dir', 'plan', 'growth', 'gr', 'g', 'option', 'opt', 'fund',
    'funds', 'the', 'scheme', 'dp', 'gw', 'mf', 'mutual', 'ltd', 'limited',
    'inc', 'corp', 'corporation', 'co', 'company', 'equity', 'shares',
    'share', 'eq', 'sh', 'of', 'and', 'a', 'nse', 'bse', //
  };
  static const _markers = {
    'regular', 'reg', 'idcw', 'dividend', 'div', 'payout', 'reinvestment',
    'bonus', 'dvr', 'pp', 'partly', 'paid', 'segregated', //
  };
  static const _amcWords = {
    'ppfas', 'hdfc', 'icici', 'prudential', 'sbi', 'axis', 'kotak', 'mahindra',
    'nippon', 'india', 'aditya', 'birla', 'sun', 'life', 'uti', 'dsp', 'tata',
    'mirae', 'asset', 'franklin', 'templeton', 'invesco', 'motilal', 'oswal',
    'quant', 'canara', 'robeco', 'edelweiss', 'hsbc', 'idfc', 'bandhan',
    'pgim', 'baroda', 'bnp', 'paribas', 'lic', 'union', 'jm', 'financial',
    'navi', 'groww', 'whiteoak', 'capital', 'samco', 'zerodha', 'helios', 'nj',
    'trust', 'iti', 'quantum', 'manulife', 'shriram', 'amc', 'investment',
    'managers', 'management', 'company', 'reliance', 'l', 't', 'lt', '360',
    'one', 'old', 'bridge', 'trustee', //
  };

  /// True when [id] is an ISIN.
  static bool isIsin(String id) => _isin.hasMatch(id);

  /// `EPF:` ids drop punctuation so SMS and passbook ids agree.
  static String normalisedId(String id) {
    if (id.startsWith('EPF:') && id != epfDefault) {
      return 'EPF:${id.substring(4).replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase()}';
    }
    return id;
  }

  /// Aggregate snapshots (`AGG:INDMONEY:<class>`).
  static bool isAggregate(String id) => id.startsWith('AGG:');

  /// Class suffix of an aggregate id (`MF`, `STOCKS`, `US`).
  static String aggregateClass(String id) =>
      id.substring(id.lastIndexOf(':') + 1);

  static Set<String> _family(HoldingKind k) => switch (k) {
        HoldingKind.mutualFund => {'fund'},
        HoldingKind.etf => {'fund', 'stock'},
        HoldingKind.stock || HoldingKind.bond => {'stock'},
        HoldingKind.gold => {'stock', 'fund'},
        _ => {k.name},
      };

  static Set<String> _words(String name) => name
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty && !_stop.contains(w))
      .toSet();

  /// Same investment under two keys.
  static bool same(HoldingKey a, HoldingKey b) {
    if (normalisedId(a.identifier) == normalisedId(b.identifier)) return true;
    if (isAggregate(a.identifier) || isAggregate(b.identifier)) return false;
    if (_family(a.kind).intersection(_family(b.kind)).isEmpty) return false;
    final aIsin = isIsin(a.identifier);
    final bIsin = isIsin(b.identifier);
    if (aIsin && bIsin) return false;
    if (a.kind == HoldingKind.epf) {
      return a.identifier == epfDefault || b.identifier == epfDefault;
    }
    if (const {HoldingKind.nps, HoldingKind.ppf, HoldingKind.fd}
        .contains(a.kind)) {
      return false;
    }
    final aUs = a.identifier.startsWith('US:');
    final bUs = b.identifier.startsWith('US:');
    if ((aUs != bUs) && !aIsin && !bIsin) return false;
    return _sameName(a.name, b.name);
  }

  static bool _sameName(String a, String b) {
    final wa = _words(a);
    final wb = _words(b);
    if (wa.isEmpty || wb.isEmpty) return false;
    if (!_setEq(wa.intersection(_markers), wb.intersection(_markers))) {
      return false;
    }
    if (_setEq(wa, wb)) return true;
    final small = wa.length <= wb.length ? wa : wb;
    final large = identical(small, wa) ? wb : wa;
    if (small.length < 2 || !large.containsAll(small)) return false;
    return large.difference(small).every(_amcWords.contains);
  }

  static bool _setEq(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  /// Identifier kept when two rows merge.
  static String preferredId(String a, String b) {
    if (isIsin(a)) return a;
    if (isIsin(b)) return b;
    if (a == epfDefault) return normalisedId(b);
    if (b == epfDefault) return normalisedId(a);
    return normalisedId(a);
  }

  /// Groups of rows (size > 1) that are one investment each.
  static List<List<T>> duplicates<T>(
    List<T> rows,
    HoldingKey Function(T) key,
  ) {
    final groups = <List<T>>[];
    for (final r in rows) {
      if (isAggregate(key(r).identifier)) continue;
      final g = groups.where((g) => same(key(g.first), key(r))).firstOrNull;
      if (g == null) {
        groups.add([r]);
      } else {
        g.add(r);
      }
    }
    return groups.where((g) => g.length > 1).toList();
  }

  /// Aggregate classes already covered by itemised holdings.
  static Set<String> aggregatesCovered(Iterable<HoldingKey> itemised) {
    final out = <String>{};
    for (final k in itemised) {
      if (isAggregate(k.identifier)) continue;
      final id = k.identifier;
      if (id.startsWith('US:') || (isIsin(id) && !id.startsWith('IN'))) {
        out.add('US');
      } else if (k.kind == HoldingKind.mutualFund) {
        out.add('MF');
      } else if (k.kind == HoldingKind.stock || k.kind == HoldingKind.etf) {
        out.add('STOCKS');
      }
    }
    return out;
  }
}
