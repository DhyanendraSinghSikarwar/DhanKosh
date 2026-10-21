import 'dart:convert';

import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/profile/domain/bank_identity.dart';
import 'package:hisaab/features/profile/domain/bank_identity_repository.dart';

/// [BankIdentityRepository] over the secure store: one sealed JSON map keyed
/// by account id (`statement_passwords.accounts`, memory 27 section 9).
class BankIdentityStore implements BankIdentityRepository {
  /// Creates the store.
  const BankIdentityStore(this._secure);

  final SecureStore _secure;

  static const _key = 'statement_passwords.accounts';

  Future<Map<String, Map<String, Object?>>> _load() async {
    final raw = await _secure.read(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, Object?>).map(
        (k, v) => MapEntry(k, (v! as Map<String, Object?>)),
      );
    } on Object {
      return {};
    }
  }

  Future<void> _store(Map<String, Map<String, Object?>> m) =>
      _secure.write(_key, jsonEncode(m));

  @override
  Future<BankIdentity?> read(int accountId) async {
    final j = (await _load())['$accountId'];
    return j == null ? null : BankIdentity.fromJson(accountId, j);
  }

  @override
  Future<List<BankIdentity>> readAll() async => [
        for (final e in (await _load()).entries)
          if (int.tryParse(e.key) != null)
            BankIdentity.fromJson(int.parse(e.key), e.value),
      ];

  @override
  Future<void> save(BankIdentity identity) async {
    final n = identity.normalised();
    final m = await _load();
    if (n.isEmpty) {
      m.remove('${n.accountId}');
    } else {
      m['${n.accountId}'] = n.toJson();
    }
    await _store(m);
  }

  @override
  Future<void> remove(int accountId) async {
    final m = await _load()
      ..remove('$accountId');
    await _store(m);
  }
}
