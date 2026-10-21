import 'dart:convert';

import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

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

/// Pack file is malformed (FR-29-05, FR-29-06).
class PackFormatException implements Exception {
  /// Creates the exception.
  const PackFormatException(this.message);

  /// Reason.
  final String message;

  @override
  String toString() => 'PackFormatException: $message';
}

/// Parses a pack `{version, code, strings}`; blank translations dropped;
/// empty result is an error (FR-29-05, FR-29-06).
Map<String, String> parsePack(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException catch (e) {
    throw PackFormatException(e.message);
  }
  if (json is! Map || json['strings'] is! Map) {
    throw const PackFormatException('missing strings');
  }
  final out = <String, String>{};
  (json['strings'] as Map).forEach((k, v) {
    if (k is String && v is String && v.trim().isNotEmpty) out[k] = v;
  });
  if (out.isEmpty) throw const PackFormatException('empty pack');
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

/// Local pack storage port (FR-29-07, FR-29-18).
abstract interface class LanguagePackStore {
  /// Languages whose pack file exists.
  Future<Set<Language>> downloaded();

  /// Raw pack body, null when missing.
  Future<String?> read(Language l);

  /// Atomically replaces the pack.
  Future<void> write(Language l, String body);

  /// Removes the pack.
  Future<void> delete(Language l);
}

/// Remote pack source port (FR-29-06).
abstract interface class LanguagePackRemote {
  /// Fetches the pack body; throws on failure.
  Future<String> fetch(Language l);
}
