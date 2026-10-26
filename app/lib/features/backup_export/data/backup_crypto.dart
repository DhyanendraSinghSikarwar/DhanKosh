import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:hisaab/features/backup_export/domain/backup_errors.dart';
import 'package:pointycastle/export.dart';

/// Encrypted backup container (FR-24-17..21):
///
/// ```text
/// "DKBK" | version u8 | iterations u32 BE | salt 16 | nonce 12 | ciphertext+tag
/// ```
///
/// The ciphertext is AES-256-GCM over gzip(JSON); the 37 header bytes are the
/// authenticated data, so changing any byte fails the tag. The key is
/// PBKDF2-HMAC-SHA256(passphrase, salt, iterations).
abstract final class BackupCrypto {
  /// File magic.
  static const magic = [0x44, 0x4b, 0x42, 0x4b];

  /// Container version written by this app.
  static const version = 1;

  /// PBKDF2 iterations written by this app (>= 200 000).
  static const defaultIterations = 210000;

  /// Accepted iteration range on read.
  static const minIterations = 1000;
  static const int _maxIterations = 5000000;

  static const _saltLen = 16;
  static const _nonceLen = 12;
  static const int _headerLen = 4 + 1 + 4 + _saltLen + _nonceLen;
  static const _tagBits = 128;

  /// Encrypts [json] with [passphrase]. Runs in a background isolate.
  static Future<Uint8List> encrypt(
    String json,
    String passphrase, {
    int iterations = defaultIterations,
  }) =>
      Isolate.run(() => encryptSync(json, passphrase, iterations: iterations));

  /// Decrypts [file]; throws [BackupFormatException] or
  /// [BackupAuthException]. Runs in a background isolate.
  static Future<String> decrypt(Uint8List file, String passphrase) =>
      Isolate.run(() => decryptSync(file, passphrase));

  /// True when [file] starts with the backup magic.
  static bool looksLikeBackup(List<int> file) =>
      file.length > _headerLen + 16 &&
      List.generate(4, (i) => file[i] == magic[i]).every((b) => b);

  /// Blocking [encrypt].
  static Uint8List encryptSync(
    String json,
    String passphrase, {
    int iterations = defaultIterations,
  }) {
    final rnd = Random.secure();
    final salt = _random(rnd, _saltLen);
    final nonce = _random(rnd, _nonceLen);
    final header = BytesBuilder()
      ..add(magic)
      ..addByte(version)
      ..add(
        (ByteData(4)..setUint32(0, iterations)).buffer.asUint8List(),
      )
      ..add(salt)
      ..add(nonce);
    final head = header.toBytes();
    final plain = Uint8List.fromList(gzip.encode(utf8.encode(json)));
    final cipher = _gcm(
      forEncryption: true,
      key: _key(passphrase, salt, iterations),
      nonce: nonce,
      aad: head,
    ).process(plain);
    return (BytesBuilder()
          ..add(head)
          ..add(cipher))
        .toBytes();
  }

  /// Blocking [decrypt].
  static String decryptSync(Uint8List file, String passphrase) {
    if (file.length < _headerLen + 16 || !looksLikeBackup(file)) {
      throw const BackupFormatException('Not a DhanKosh backup file');
    }
    final v = file[4];
    if (v != version) {
      throw BackupFormatException(
        v > version
            ? 'Backup is from a newer app version. Update DhanKosh'
            : 'Unsupported backup version',
      );
    }
    final iterations = ByteData.sublistView(file, 5, 9).getUint32(0);
    if (iterations < minIterations || iterations > _maxIterations) {
      throw const BackupFormatException('Not a DhanKosh backup file');
    }
    final salt = Uint8List.sublistView(file, 9, 9 + _saltLen);
    final nonce = Uint8List.sublistView(file, 25, _headerLen);
    final head = Uint8List.sublistView(file, 0, _headerLen);
    final body = Uint8List.sublistView(file, _headerLen);
    final Uint8List plain;
    try {
      plain = _gcm(
        forEncryption: false,
        key: _key(passphrase, salt, iterations),
        nonce: nonce,
        aad: head,
      ).process(body);
    } on InvalidCipherTextException {
      throw const BackupAuthException();
    } on Exception {
      throw const BackupAuthException();
    }
    try {
      return utf8.decode(gzip.decode(plain));
    } on Object {
      throw const BackupFormatException('Backup content is unreadable');
    }
  }

  static Uint8List _random(Random r, int n) =>
      Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));

  static Uint8List _key(String pass, Uint8List salt, int iterations) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(pass)));
  }

  static GCMBlockCipher _gcm({
    required bool forEncryption,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
  }) =>
      GCMBlockCipher(AESEngine())
        ..init(
          forEncryption,
          AEADParameters(KeyParameter(key), _tagBits, nonce, aad),
        );
}
