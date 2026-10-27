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

/// Mails a short message to the address itself over SMTP with the user's own
/// app password (FR-03-03). Failures are `AuthFailure`, `NetworkFailure` or
/// `TlsFailure`.
abstract interface class MailSender {
  /// Sends [subject] and [body] from [account] to [account].
  Future<void> sendToSelf(
    EmailAccount account,
    String password, {
    required String subject,
    required String body,
  });
}

/// Non-secret email settings and sync state, one entry per mailbox
/// (FR-03-06).
abstract interface class EmailSettingsRepository {
  /// Saved mailboxes, oldest first.
  Future<List<EmailAccount>> accounts();

  /// First saved mailbox, or null when none is connected.
  Future<EmailAccount?> account() async {
    final all = await accounts();
    return all.isEmpty ? null : all.first;
  }

  /// Adds or replaces the mailbox (by address) and clears its `needsReauth`
  /// and cursor.
  Future<void> saveAccount(EmailAccount account);

  /// Turns one mailbox on or off.
  Future<void> setEnabled(String address, {required bool enabled});

  /// Forgets one mailbox and its sync state.
  Future<void> removeAccount(String address);

  /// Epoch ms of the last clean sync of [address]; 0 = never (full read).
  Future<int> lastSyncAt(String address);

  /// Records a sync result (cursor only moves on success).
  Future<void> saveSync(
    String address, {
    required int at,
    required String report,
  });

  /// Stores a result without moving the cursor.
  Future<void> saveReport(String address, String report);

  /// Clears the cursor of every mailbox so older mail is re-read (FR-03-12).
  Future<void> forgetPosition();

  /// Last report text of [address], or null.
  Future<String?> lastReport(String address);

  /// Look-back window in days (shared with SMS, FR-03-19).
  Future<int> lookbackDays();

  /// Whether the login of [address] stopped working.
  Future<bool> needsReauth(String address);

  /// Sets or clears the sign-in-again flag.
  Future<void> setNeedsReauth(String address, {required bool value});

  /// User-added senders (shared by all mailboxes).
  Future<Set<String>> customSenders();

  /// Replaces the user-added senders and forgets the position.
  Future<void> saveCustomSenders(Set<String> senders);

  /// Default senders and domains the user switched off (FR-26-31).
  Future<Set<String>> removedDefaultSenders();

  /// Replaces the switched-off defaults and forgets the position.
  Future<void> saveRemovedDefaultSenders(Set<String> senders);
}

/// App passwords in secure storage only, one per mailbox (FR-03-05).
abstract interface class EmailCredentialStore {
  /// Stored password of [address], or null.
  Future<String?> read(String address);

  /// Seals [password] for [address].
  Future<void> write(String address, String password);

  /// Wipes the password of [address].
  Future<void> wipe(String address);
}

/// Message ids already handled (FR-03-10).
abstract interface class ProcessedEmailRepository {
  /// Which of [ids] were handled before.
  Future<Set<String>> processed(Iterable<String> ids);

  /// Records [id] with `PARSED`, `REJECTED` or `SKIPPED`.
  Future<void> mark(String id, String outcome, {required int at});
}
