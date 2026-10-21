import 'dart:convert';

import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';

/// [IdentityRepository] sealing the identity in one [SecureStore] entry
/// (FR-01-07: alternates, PAN and DOB live only here).
class IdentityStore implements IdentityRepository {
  /// Creates the store.
  const IdentityStore(this._secure);

  final SecureStore _secure;

  static const _key = 'identity_v1';

  @override
  Future<Identity?> read() async {
    final raw = await _secure.read(_key);
    if (raw == null) return null;
    try {
      return Identity.fromJson(
        (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(Identity identity) =>
      _secure.write(_key, jsonEncode(identity.toJson()));
}
