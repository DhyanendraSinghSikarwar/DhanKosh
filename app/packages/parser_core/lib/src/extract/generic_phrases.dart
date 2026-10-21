/// Button and link captions from payment-app notifications and emails, which
/// are never a merchant name (FR-06-07).
abstract final class GenericPhrases {
  static const _phrases = {
    'view details', 'view detail', 'view', 'details', 'view receipt',
    'view transaction', 'view statement', 'view more', 'click here', 'click',
    'know more', 'check balance', 'tap to view', 'tap here', 'download',
    'pay now', 'learn more', 'track order', 'explore', 'open app', 'open',
    'see details', 'see more', 'show details', 'view order', 'check now',
    'get started', 'shop now', 'register now', 'apply now', 'unsubscribe', //
  };
  static final _nonLetters = RegExp('[^a-z ]');
  static final _spaces = RegExp(r'\s+');

  /// True for a UI phrase, or one made of nothing else.
  static bool isGeneric(String? name) {
    if (name == null) return false;
    final k = name
        .toLowerCase()
        .replaceAll(_nonLetters, ' ')
        .trim()
        .replaceAll(_spaces, ' ');
    return _phrases.contains(k);
  }

  /// [name] unless it is a UI phrase.
  static String? clean(String? name) => isGeneric(name) ? null : name;
}
