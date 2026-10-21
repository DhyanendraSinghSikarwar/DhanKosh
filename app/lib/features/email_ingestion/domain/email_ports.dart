import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';

/// Mailbox access over IMAP. Failures are `AuthFailure`, `NetworkFailure`
/// or `TlsFailure` (FR-03-02, FR-03-18).
abstract interface class ImapClient {
  /// Connects, signs in and closes. Proves the login works.
  Future<void> testLogin(EmailAccount account, String password);

  /// Mail received on or after [since] (date granularity) for which
  /// [accept] says yes, oldest first, at most [limit]. Bodies are fetched
  /// only for accepted mail (FR-03-09).
  Future<List<RawEmail>> fetchSince(
    EmailAccount account,
    String password, {
    required DateTime since,
    required bool Function(String from, String subject) accept,
    int limit = 300,
  });
}

/// Non-secret email settings and sync state.
abstract interface class EmailSettingsRepository {
  /// Saved account, or null when not connected.
  Future<EmailAccount?> account();

  /// Saves the account and clears `needsReauth`.
  Future<void> saveAccount(EmailAccount account);

  /// Forgets the account and sync state.
  Future<void> clearAccount();

  /// Epoch ms of the last clean sync; 0 = never (full read).
  Future<int> lastSyncAt();

  /// Records a sync result (cursor only moves on success).
  Future<void> saveSync({required int at, required String report});

  /// Stores a result without moving the cursor.
  Future<void> saveReport(String report);

  /// Clears the cursor so older mail is re-read (FR-03-12).
  Future<void> forgetPosition();

  /// Last report text, or null.
  Future<String?> lastReport();

  /// Look-back window in days (shared with SMS, FR-03-19).
  Future<int> lookbackDays();

  /// Whether the login stopped working.
  Future<bool> needsReauth();

  /// Sets or clears the sign-in-again flag.
  Future<void> setNeedsReauth({required bool value});

  /// User-added senders.
  Future<Set<String>> customSenders();

  /// Replaces the user-added senders and forgets the position.
  Future<void> saveCustomSenders(Set<String> senders);
}

/// App password in secure storage only (FR-03-05).
abstract interface class EmailCredentialStore {
  /// Stored password, or null.
  Future<String?> read();

  /// Seals [password].
  Future<void> write(String password);

  /// Wipes the password.
  Future<void> wipe();
}

/// Message ids already handled (FR-03-10).
abstract interface class ProcessedEmailRepository {
  /// Which of [ids] were handled before.
  Future<Set<String>> processed(Iterable<String> ids);

  /// Records [id] with `PARSED`, `REJECTED` or `SKIPPED`.
  Future<void> mark(String id, String outcome, {required int at});
}
