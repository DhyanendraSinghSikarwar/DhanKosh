import 'package:hisaab/features/credit_cards/domain/card_matcher.dart';

/// Storage keys of card notices (FR-14-06).
abstract final class CardNoticeKeys {
  static String _bank(String? bank) =>
      bank == null || bank.isEmpty ? 'any' : CardMatcher.issuerKey(bank);

  /// `carddue:<bank>:<last4 or "any"+total>:<day>`.
  static String due({
    required int day,
    String? bank,
    String? last4,
    int? totalMinor,
  }) =>
      'carddue:${_bank(bank)}:'
      '${(last4 == null || last4.isEmpty) ? 'any${totalMinor ?? ''}' : last4}:$day';

  /// `cardpay:<bank>:<last4>:<day>:<amount>`.
  static String payment({
    required int day,
    required int amountMinor,
    String? bank,
    String? last4,
  }) =>
      'cardpay:${_bank(bank)}:${last4 ?? 'any'}:$day:$amountMinor';
}
