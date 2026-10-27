import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Outcome of checking a typed code (FR-03-03).
enum VerificationResult { ok, wrong, expired, tooManyAttempts, none }

/// A one-time 6-digit code mailed to the address being connected. Kept in
/// memory as a hash; expires after [ttl] and allows [maxAttempts] wrong tries
/// (same rules as the Kotlin app).
class VerificationCode {
  /// Creates a holder; [clock] and [random] are injectable for tests.
  VerificationCode({
    DateTime Function()? clock,
    Random? random,
    this.ttl = const Duration(minutes: 10),
    this.maxAttempts = 5,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure();

  final DateTime Function() _clock;
  final Random _random;

  /// Time a code stays valid.
  final Duration ttl;

  /// Wrong tries allowed per code.
  final int maxAttempts;

  String? _hash;
  String? _address;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _attempts = 0;

  /// Makes a fresh code for [address], replacing any earlier one.
  String issue(String address) {
    final code = '${_random.nextInt(900000) + 100000}';
    _hash = _digest(address, code);
    _address = address;
    _expiresAt = _clock().add(ttl);
    _attempts = 0;
    return code;
  }

  /// Checks [typed] (non-digits ignored) for [address].
  VerificationResult check(String address, String typed) {
    final expected = _hash;
    if (expected == null || _address != address) return VerificationResult.none;
    if (_clock().isAfter(_expiresAt)) return VerificationResult.expired;
    if (_attempts >= maxAttempts) return VerificationResult.tooManyAttempts;
    _attempts++;
    final ok =
        _digest(address, typed.replaceAll(RegExp(r'\D'), '')) == expected;
    if (ok) clear();
    return ok ? VerificationResult.ok : VerificationResult.wrong;
  }

  /// Forgets the code.
  void clear() {
    _hash = null;
    _address = null;
    _attempts = 0;
  }

  static String _digest(String address, String code) =>
      sha256.convert(utf8.encode('$address|$code')).toString();
}
