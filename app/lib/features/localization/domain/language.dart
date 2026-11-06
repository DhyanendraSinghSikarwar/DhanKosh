import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:yaml/yaml.dart';

/// Supported languages (FR-29-04); English is built in.
enum Language {
  en('English', 'English'),
  hi('Hindi', 'हिन्दी'),
  bn('Bengali', 'বাংলা'),
  te('Telugu', 'తెలుగు'),
  mr('Marathi', 'मराठी'),
  ta('Tamil', 'தமிழ்'),
  gu('Gujarati', 'ગુજરાતી'),
  kn('Kannada', 'ಕನ್ನಡ');

  const Language(this.english, this.native);

  /// English name.
  final String english;

  /// Native name.
  final String native;

  /// Pack code.
  String get code => name;

  /// Built-in flag.
  bool get builtIn => this == en;

  /// Language by code; English when null or unknown.
  static Language of(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => en);
}

/// Persisted active language code (FR-29-08).
const languageKey = SettingKey<String>('language', 'en');

/// A catalogue file is malformed (FR-29-05).
class CatalogueFormatException implements Exception {
  /// Creates the exception.
  const CatalogueFormatException(this.message);

  /// Reason.
  final String message;

  @override
  String toString() => 'CatalogueFormatException: $message';
}

/// Parses a catalogue (`assets/l10n/<code>.yaml`): `version`, `code` and a
/// `strings` map of English text to translation. Blank translations are
/// ignored, so a string still waiting for its translation shows in English
/// (FR-29-05).
Map<String, String> parseCatalogue(String body) {
  final Object? doc;
  try {
    doc = loadYaml(body);
  } on YamlException catch (e) {
    throw CatalogueFormatException(e.message);
  }
  if (doc is! Map || doc['strings'] is! Map) {
    throw const CatalogueFormatException('missing strings');
  }
  final out = <String, String>{};
  (doc['strings'] as Map).forEach((k, v) {
    if (k is String && v is String && v.trim().isNotEmpty) out[k] = v;
  });
  return out;
}

/// Pure translator: English text is the key (FR-29-01).
class Translator {
  /// Creates a translator over [strings] (empty means English).
  const Translator([this.strings = const {}]);

  /// English to translation.
  final Map<String, String> strings;

  /// Translates [english], then fills `{name}` placeholders.
  String call(String english, {Map<String, Object?> args = const {}}) {
    var s = strings[english] ?? english;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  /// Plural by separate keys (FR-29-16).
  String plural(int n, String one, String other) =>
      call(n == 1 ? one : other, args: {'n': n});
}

/// Process-wide active translator behind [t].
abstract final class I18n {
  /// Active translator.
  static Translator current = const Translator();
}

/// Translates [english] in the active language (FR-29-01).
String t(String english, {Map<String, Object?> args = const {}}) =>
    I18n.current(english, args: args);

/// Where catalogues come from: the app's bundled files (FR-29-05).
abstract interface class LanguageCatalogue {
  /// The raw YAML of [l], or null when the language has no file.
  Future<String?> load(Language l);
}
