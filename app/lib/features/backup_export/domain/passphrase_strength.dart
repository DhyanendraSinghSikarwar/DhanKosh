/// Passphrase strength hint (FR-24-24). A rough guide, not a guarantee.
enum PassphraseStrength {
  /// Under 8 characters, or one repeated character.
  weak,

  /// 8 to 11 characters or little variety.
  fair,

  /// 12 or more characters with variety.
  strong;

  /// Short label for the UI.
  String get label => switch (this) {
        PassphraseStrength.weak => 'Weak',
        PassphraseStrength.fair => 'Fair',
        PassphraseStrength.strong => 'Strong',
      };

  /// Minimum length to allow an export.
  static const minLength = 8;

  /// Rates [p].
  static PassphraseStrength of(String p) {
    if (p.length < minLength || p.runes.toSet().length < 4) {
      return PassphraseStrength.weak;
    }
    var classes = 0;
    if (RegExp('[a-z]').hasMatch(p)) classes++;
    if (RegExp('[A-Z]').hasMatch(p)) classes++;
    if (RegExp('[0-9]').hasMatch(p)) classes++;
    if (RegExp('[^A-Za-z0-9]').hasMatch(p)) classes++;
    if (p.length >= 12 && classes >= 2) return PassphraseStrength.strong;
    if (p.length >= 16) return PassphraseStrength.strong;
    return PassphraseStrength.fair;
  }
}
