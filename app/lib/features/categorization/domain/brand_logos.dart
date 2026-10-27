import 'package:hisaab/features/categorization/domain/brand_logo_rules.dart';

/// Offline mapping from a bank, payment app or merchant name to a bundled
/// logo key (FR-09-32). A key `k` is the asset `assets/logos/k.webp`; nothing
/// is fetched at run time. Logos are the owners' trademarks, shown only to
/// identify the user's own accounts and payees (memory 09 licence note).
abstract final class BrandLogos {
  static final List<(RegExp, String)> _banks = _compile(banksRules);
  static final List<(RegExp, String)> _specific = _compile(specificRules);
  static final List<(RegExp, String)> _merchants = _compile(merchantsRules);
  static final List<(RegExp, String)> _generic = _compile(genericRules);

  static List<(RegExp, String)> _compile(List<(String, String)> rules) => [
        for (final (p, k) in rules) (RegExp(p, caseSensitive: false), k),
      ];

  static String? _first(List<(RegExp, String)> rules, String name) {
    for (final (re, key) in rules) {
      if (re.hasMatch(name)) return key;
    }
    return null;
  }

  /// Logo key of a bank or card issuer name, or null.
  static String? bank(String? name) =>
      name == null ? null : _first(_banks, name);

  /// Logo key of a merchant or payment app name, or null. Specific brands are
  /// checked first, broad names (Google, Apple) last.
  static String? merchant(String? name) => name == null
      ? null
      : _first(_specific, name) ??
          _first(_merchants, name) ??
          _first(_generic, name);

  /// Every key the rules can return; each must have an asset.
  static Set<String> get allKeys => {
        for (final r in [
          ...banksRules,
          ...specificRules,
          ...merchantsRules,
          ...genericRules,
        ])
          r.$2,
      };

  /// Asset path of [key].
  static String assetPath(String key) => 'assets/logos/$key.webp';
}
