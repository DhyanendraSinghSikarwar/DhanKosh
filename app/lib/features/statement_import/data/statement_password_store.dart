import 'dart:convert';

import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/statement_import/domain/saved_password.dart';

/// [SavedPasswordRepository] over the secure store (FR-05-10): one sealed
/// JSON list, never shown again.
class StatementPasswordStore implements SavedPasswordRepository {
  /// Creates the store.
  const StatementPasswordStore(this._secure);

  final SecureStore _secure;

  static const _key = 'statement_passwords.entries';

  @override
  Future<List<SavedPassword>> list() async {
    final raw = await _secure.read(_key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List<Object?>)
          SavedPassword(
            label: (e! as Map<String, Object?>)['label']! as String,
            secret: e['secret']! as String,
          ),
      ];
    } on Object {
      return [];
    }
  }

  Future<void> _store(List<SavedPassword> l) => _secure.write(
        _key,
        jsonEncode([
          for (final p in l) {'label': p.label, 'secret': p.secret},
        ]),
      );

  @override
  Future<void> add(SavedPassword p) async {
    final l = [
      for (final e in await list())
        if (e.label != p.label) e,
      p,
    ];
    await _store(l);
  }

  @override
  Future<void> remove(String label) async {
    await _store([
      for (final e in await list())
        if (e.label != label) e,
    ]);
  }
}
