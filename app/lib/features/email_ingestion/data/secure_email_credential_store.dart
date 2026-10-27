import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';

/// App passwords in the Keystore-backed [SecureStore], one key per mailbox
/// (FR-03-05, FR-03-06). Wiping overwrites with an empty value, which reads
/// as absent.
class SecureEmailCredentialStore implements EmailCredentialStore {
  /// Creates the store.
  const SecureEmailCredentialStore(this._secure);

  final SecureStore _secure;

  static const _prefix = 'email_app_password';

  static String _key(String address) =>
      '$_prefix:${address.trim().toLowerCase()}';

  @override
  Future<String?> read(String address) async {
    final v = await _secure.read(_key(address));
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> write(String address, String password) =>
      _secure.write(_key(address), password);

  @override
  Future<void> wipe(String address) async {
    await _secure.write(_key(address), '');
  }
}
