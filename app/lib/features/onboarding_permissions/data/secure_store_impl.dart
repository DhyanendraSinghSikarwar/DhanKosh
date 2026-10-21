import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';

/// [SecureStore] over `flutter_secure_storage` (Android Keystore backed).
class SecureStoreImpl implements SecureStore {
  /// Creates the store; `storage` is injectable for tests.
  const SecureStoreImpl([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
