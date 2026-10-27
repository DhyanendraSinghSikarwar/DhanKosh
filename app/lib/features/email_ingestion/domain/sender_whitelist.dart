import 'package:parser_core/parser_core.dart';

/// Which senders may be read (FR-03-12): default bank and statement domains
/// plus the user's own entries; statement-like subjects always pass.
class SenderWhitelist {
  /// Creates a whitelist from [defaults] and user [custom] entries.
  SenderWhitelist({
    Iterable<String>? defaults,
    Iterable<String> custom = const [],
    Iterable<String> removed = const [],
  })  : defaults = _clean(defaults ?? standardDefaults())
          ..removeAll(_clean(removed)),
        custom = _clean(custom);

  /// Defaults from the parser registry (banks plus statement senders).
  static Set<String> standardDefaults() =>
      ParserRegistry.standard().defaultEmailSenders.toSet();

  /// Built-in entries still on, lower-case (switched-off ones are left out).
  final Set<String> defaults;

  /// User-added entries (address or domain), lower-case.
  final Set<String> custom;

  /// Defaults plus custom.
  Set<String> get all => {...defaults, ...custom};

  static Set<String> _clean(Iterable<String> items) => {
        for (final s in items)
          if (_valid(s.trim().toLowerCase())) s.trim().toLowerCase(),
      };

  static bool _valid(String s) =>
      s.isNotEmpty && !s.contains(' ') && (s.contains('.') || s.contains('@'));

  /// Normalised entry for user input, or null when not an address/domain.
  static String? normalize(String input) {
    final s = input.trim().toLowerCase();
    return _valid(s) ? s : null;
  }

  /// True when [from] (or its domain) is listed, or [subject] looks like a
  /// statement.
  bool allows(String from, String subject) {
    final all = this.all;
    return SenderKeys.candidates(from).any(all.contains) ||
        ParserRegistry.isStatementSubject(subject);
  }
}
