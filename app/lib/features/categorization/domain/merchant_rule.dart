import 'package:parser_core/parser_core.dart';

enum RuleMatch { exact, contains }

/// A learned (`manual == false`) or user-made category rule (FR-09-06..10).
class MerchantRule {
  const MerchantRule({
    required this.merchantKey,
    required this.category,
    required this.updatedAt,
    this.matchType = RuleMatch.exact,
    this.subcategory,
    this.customCategoryId,
    this.manual = false,
  });

  /// Lower-cased merchant, UPI id or contains-text; the primary key.
  final String merchantKey;
  final Category category;
  final int updatedAt;
  final RuleMatch matchType;
  final String? subcategory;
  final int? customCategoryId;
  final bool manual;

  /// Rule keys shorter than this are ignored.
  static const minKey = 2;

  /// `(merchant ?: upiId).trim().lowercase()`, or null when under [minKey].
  static String? keyOf(String? merchant, String? upiId) {
    final k = (merchant ?? upiId)?.trim().toLowerCase();
    return (k == null || k.length < minKey) ? null : k;
  }
}

/// All rules, loaded once per ingest batch (FR-09-10).
class RuleSet {
  const RuleSet(this.rules);

  static const empty = RuleSet([]);
  final List<MerchantRule> rules;

  /// Best rule: manual EXACT, longest manual CONTAINS, then learned EXACT.
  /// Never for transfers.
  MerchantRule? ruleFor({
    required String? merchant,
    required String? upiId,
    required TransactionType type,
  }) {
    if (type == TransactionType.transfer) return null;
    final m = merchant?.trim().toLowerCase();
    final u = upiId?.trim().toLowerCase();
    final manual = rules.where((r) => r.manual).toList();
    for (final r in manual) {
      if (r.matchType == RuleMatch.exact &&
          (r.merchantKey == m || r.merchantKey == u)) {
        return r;
      }
    }
    final hay = '${m ?? ''} ${u ?? ''}';
    MerchantRule? longest;
    for (final r in manual) {
      if (r.matchType == RuleMatch.contains &&
          hay.contains(r.merchantKey) &&
          (longest == null ||
              r.merchantKey.length > longest.merchantKey.length)) {
        longest = r;
      }
    }
    if (longest != null) return longest;
    final key = MerchantRule.keyOf(merchant, upiId);
    if (key == null) return null;
    for (final r in rules) {
      if (!r.manual && r.merchantKey == key) return r;
    }
    return null;
  }
}
