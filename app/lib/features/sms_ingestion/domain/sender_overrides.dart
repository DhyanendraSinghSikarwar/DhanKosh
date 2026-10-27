import 'dart:convert';

import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';
import 'package:parser_core/parser_core.dart';

/// The user's edits to the bank sender list (FR-26-31): SMS sender ids such as
/// `HDFCBK` and mail domains such as `hdfcbank.net`. Defaults come from the
/// parser registry; these are added on top or taken out.
class SenderOverrides {
  /// Creates a set of edits (keys already normalised).
  const SenderOverrides({this.added = const {}, this.removed = const {}});

  /// No edits: the registry decides alone.
  static const none = SenderOverrides();

  /// Extra senders the user wants read.
  final Set<String> added;

  /// Default senders the user switched off.
  final Set<String> removed;

  /// True when nothing is edited.
  bool get isEmpty => added.isEmpty && removed.isEmpty;

  /// Normal form of user input: an SMS sender id is upper-case letters and
  /// digits (3 to 11), a domain is lower-case with a dot. Null when invalid.
  static String? normalize(String input) {
    final s = input.trim();
    if (s.isEmpty || s.contains(' ')) return null;
    if (s.contains('@') || s.contains('.')) {
      final d = s.toLowerCase();
      final domain = d.contains('@') ? d.substring(d.lastIndexOf('@') + 1) : d;
      return RegExp(r'^([a-z0-9\-]+\.)+[a-z]{2,}$').hasMatch(domain)
          ? domain
          : null;
    }
    final id = SenderKeys.smsHeader(s);
    return RegExp(r'^[A-Z0-9]{3,11}$').hasMatch(id) ? id : null;
  }

  /// Whether the user switched [sender] off.
  bool blocks(String sender) =>
      removed.isNotEmpty && SenderKeys.candidates(sender).any(removed.contains);

  /// Whether the user added [sender].
  bool allows(String sender) =>
      added.isNotEmpty && SenderKeys.candidates(sender).any(added.contains);

  /// Copy with [added] and [removed].
  SenderOverrides copyWith({Set<String>? added, Set<String>? removed}) =>
      SenderOverrides(
        added: added ?? this.added,
        removed: removed ?? this.removed,
      );
}

/// Default sender keys from the parser registry: SMS ids and mail domains.
({List<String> sms, List<String> mail}) defaultSenderKeys() {
  final keys = <String>{
    for (final p in ParserRegistry.standard().parsers) ...p.senderKeys,
  };
  final sms = keys.where((k) => !k.contains('.')).toList()..sort();
  final mail = keys.where((k) => k.contains('.')).toList()..sort();
  return (sms: sms, mail: mail);
}

/// Persistence of [SenderOverrides].
abstract interface class SenderOverridesStore {
  /// Saved edits.
  Future<SenderOverrides> read();

  /// Replaces the edits.
  Future<void> save(SenderOverrides overrides);
}

/// [SenderOverridesStore] over the settings key-value store.
class KvSenderOverridesStore implements SenderOverridesStore {
  /// Creates the store.
  const KvSenderOverridesStore(this._kv);

  final KeyValueStore _kv;

  static const _key = 'sms_sender_overrides';

  @override
  Future<SenderOverrides> read() async {
    final raw = await _kv.getString(_key);
    if (raw == null || raw.isEmpty) return SenderOverrides.none;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return SenderOverrides(
        added: {...(m['added'] as List? ?? const []).cast<String>()},
        removed: {...(m['removed'] as List? ?? const []).cast<String>()},
      );
    } on Object {
      return SenderOverrides.none;
    }
  }

  @override
  Future<void> save(SenderOverrides o) => _kv.setString(
        _key,
        o.isEmpty
            ? ''
            : jsonEncode({
                'added': o.added.toList()..sort(),
                'removed': o.removed.toList()..sort(),
              }),
      );
}

/// In-memory copy of the edits for the synchronous pre-filter (FR-26-31).
/// Loaded once by the ingest use case; refreshed after each edit.
/// See `UserSenderParser` for how added senders are parsed.
class SenderOverridesCache {
  /// Creates the cache over a store.
  SenderOverridesCache(this._store);

  final SenderOverridesStore _store;
  SenderOverrides _current = SenderOverrides.none;
  Future<void>? _loading;

  /// Latest loaded edits ([SenderOverrides.none] until loaded).
  SenderOverrides get current => _current;

  /// Loads once; later calls join the first.
  Future<void> ensureLoaded() => _loading ??= refresh();

  /// Reads the edits again.
  Future<void> refresh() async {
    try {
      _current = await _store.read();
    } on Object {
      _current = SenderOverrides.none;
    }
  }

  /// Saves [o] and uses it from now on.
  Future<void> save(SenderOverrides o) async {
    await _store.save(o);
    _current = o;
    _loading ??= Future.value();
  }
}

/// Reads alerts from senders the user added: accepted like any bank sender
/// (extends `GenericBankParser`).
class UserSenderParser extends GenericBankParser {
  /// Creates the parser for [keys] (normalised sender ids and domains).
  UserSenderParser(this.keys);

  /// Added sender keys.
  final Set<String> keys;

  @override
  bool canHandle(String sender, String body) =>
      SenderKeys.candidates(sender).any(keys.contains) ||
      super.canHandle(sender, body);
}
