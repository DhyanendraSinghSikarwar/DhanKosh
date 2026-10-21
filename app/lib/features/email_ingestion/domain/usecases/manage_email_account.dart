import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/sender_whitelist.dart';

/// Connect, test, disconnect and sender edits (FR-03-05, FR-03-06,
/// FR-03-12). The password goes to secure storage only.
class ManageEmailAccount {
  /// Creates the use case.
  ManageEmailAccount({
    required ImapClient imap,
    required EmailSettingsRepository settings,
    required EmailCredentialStore credentials,
  })  : _imap = imap,
        _settings = settings,
        _credentials = credentials;

  final ImapClient _imap;
  final EmailSettingsRepository _settings;
  final EmailCredentialStore _credentials;

  /// Form error for the input, or null when it can be used (FR-03-01).
  static String? validate(String address, String password, {String? host}) {
    if (!EmailAccount.isValidAddress(address)) {
      return 'Enter a full email address';
    }
    if (EmailAccount.cleanPassword(password).isEmpty) {
      return 'Enter the app password';
    }
    if (host != null && host.trim().isEmpty) return 'Enter the IMAP server';
    return null;
  }

  /// Signs in and closes; throws `AuthFailure`, `NetworkFailure` or
  /// `TlsFailure`. Saves nothing.
  Future<void> test(EmailAccount account, String password) =>
      _imap.testLogin(account, EmailAccount.cleanPassword(password));

  /// Seals the password and saves the account.
  Future<void> save(EmailAccount account, String password) async {
    await _credentials.write(EmailAccount.cleanPassword(password));
    await _settings.saveAccount(account);
    await _settings.forgetPosition();
  }

  /// Wipes the password and forgets the account; transactions stay.
  Future<void> disconnect() async {
    await _credentials.wipe();
    await _settings.clearAccount();
  }

  /// Adds one address or domain; returns false when it is not valid.
  Future<bool> addSender(String input) async {
    final s = SenderWhitelist.normalize(input);
    if (s == null) return false;
    final now = await _settings.customSenders();
    if (!now.contains(s)) await _settings.saveCustomSenders({...now, s});
    return true;
  }

  /// Removes a user-added sender.
  Future<void> removeSender(String sender) async {
    final now = await _settings.customSenders();
    if (now.contains(sender)) {
      await _settings.saveCustomSenders({...now}..remove(sender));
    }
  }

  /// Back to the default list.
  Future<void> resetSenders() => _settings.saveCustomSenders(const {});
}
