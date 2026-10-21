import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Supplies the SQLCipher key. The key never leaves the device.
// ignore: one_member_abstracts
abstract interface class DbKeyStore {
  /// Returns the existing key (64 hex chars) or creates and stores one.
  Future<String> getOrCreateKey();
}

/// Generates a 256-bit key as 64 lowercase hex characters.
String generateDbKeyHex(Random random) {
  final buf = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buf.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

/// Keeps the key in `flutter_secure_storage` (Android Keystore backed).
class SecureStorageDbKeyStore implements DbKeyStore {
  /// Creates the store; [storage] and [random] are injectable for tests.
  SecureStorageDbKeyStore({FlutterSecureStorage? storage, Random? random})
      : _storage = storage ?? const FlutterSecureStorage(),
        _random = random ?? Random.secure();

  static const _keyName = 'hisaab_db_key_v1';

  final FlutterSecureStorage _storage;
  final Random _random;

  @override
  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.length == 64) return existing;
    final key = generateDbKeyHex(_random);
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}
