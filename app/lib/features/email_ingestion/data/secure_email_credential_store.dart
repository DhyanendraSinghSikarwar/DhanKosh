import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';

/// App password in the Keystore-backed [SecureStore] (FR-03-05). Wiping
/// overwrites with an empty value, which reads as absent.
class SecureEmailCredentialStore implements EmailCredentialStore {
  /// Creates the store.
  const SecureEmailCredentialStore(this._secure);

  final SecureStore _secure;

  static const _key = 'email_app_password';

  @override
  Future<String?> read() async {
    final v = await _secure.read(_key);
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> write(String password) => _secure.write(_key, password);

  @override
  Future<void> wipe() => _secure.write(_key, '');
}
