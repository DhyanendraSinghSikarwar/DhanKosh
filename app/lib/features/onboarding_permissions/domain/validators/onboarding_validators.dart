/// Input rules for Welcome (FR-01-04, FR-01-05).
abstract final class OnboardingValidators {
  static final _pan = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

  /// Digits only, capped at 10. A leading `91` (as in the stored
  /// `+91 NNNNNNNNNN`) or `0` is dropped first, so a saved number reloads whole.
  static String phoneDigits(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.length > 10 && d.startsWith('91')) {
      d = d.substring(2);
    } else if (d.length > 10 && d.startsWith('0')) {
      d = d.substring(1);
    }
    return d.length > 10 ? d.substring(0, 10) : d;
  }

  /// True for exactly 10 digits.
  static bool isValidPhone(String input) => phoneDigits(input).length == 10;

  /// `+91 NNNNNNNNNN`, or null when not exactly 10 digits.
  static String? formatPhone(String input) =>
      isValidPhone(input) ? '+91 ${phoneDigits(input)}' : null;

  /// Blank or `[A-Z]{5}[0-9]{4}[A-Z]` after trim and upper-casing
  /// (case handling is an open question in the feature memory).
  static bool isValidPanOrBlank(String input) {
    final p = input.trim().toUpperCase();
    return p.isEmpty || _pan.hasMatch(p);
  }
}
