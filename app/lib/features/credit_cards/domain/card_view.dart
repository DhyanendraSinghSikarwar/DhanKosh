import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Stored limit overrides, `bank:last4=paise` pairs joined by `;`
/// (FR-14-26). Empty when none.
const cardLimitOverridesKey = SettingKey<String>('card_limit_overrides', '');

/// Parses and writes the limit-override setting value.
abstract final class CardLimitOverrides {
  /// Map of card key to paise; bad pairs are ignored.
  static Map<String, int> parse(String raw) {
    final out = <String, int>{};
    for (final pair in raw.split(';')) {
      final i = pair.lastIndexOf('=');
      if (i <= 0) continue;
      final v = int.tryParse(pair.substring(i + 1));
      if (v != null && v >= 0) out[pair.substring(0, i)] = v;
    }
    return out;
  }

  /// Inverse of [parse].
  static String encode(Map<String, int> m) =>
      m.entries.map((e) => '${e.key}=${e.value}').join(';');
}

/// A card as Home and the card page show it: the calculated position plus
/// the user's limit override and the account's Book (FR-14-24..27).
class CardView {
  /// Creates a view.
  const CardView({
    required this.card,
    required this.usage,
    this.limitOverrideMinor,
  });

  /// Card with its position (statement, unbilled, min due already merged
  /// with the user's edits).
  final CardLimit card;

  /// Book of the card's account.
  final AccountUsage usage;

  /// User-set limit, paise; null when none.
  final int? limitOverrideMinor;

  /// Limit shown: the override, else the statement's.
  int? get limitMinor => limitOverrideMinor ?? card.limitMinor;

  /// Limit was edited by the user.
  bool get limitEdited => limitOverrideMinor != null;

  /// Any figure was edited by the user.
  bool get edited => card.position.edited || limitEdited;

  /// Statement balance: billed, else the outstanding figure.
  int get dueMinor => card.owedMinor;

  /// Available limit: `limit - (billed + unbilled)` floored at 0 when the
  /// limit or an amount was edited, else the card's own figure (FR-14-14).
  int? get availableMinor {
    final limit = limitMinor;
    if (limitEdited && limit != null) {
      final left = limit - (card.position.totalMinor ?? 0);
      return left < 0 ? 0 : left;
    }
    return card.limitLeftMinor ??
        (limit == null
            ? null
            : (limit - (card.position.totalMinor ?? 0)).clamp(0, limit));
  }

  /// Share of the limit used, 0..1; null without a limit.
  double? get usedFraction {
    final limit = limitMinor;
    final left = availableMinor;
    if (limit == null || limit <= 0 || left == null) return null;
    return ((limit - left) / limit).clamp(0.0, 1.0);
  }
}
