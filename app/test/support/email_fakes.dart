import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';

/// Fake IMAP: serves [mails] through the real accept filter, or throws
/// [error]. Records what it was asked.
class FakeImap implements ImapClient {
  FakeImap([this.mails = const []]);

  List<RawEmail> mails;
  Failure? error;
  DateTime? lastSince;
  String? lastPassword;
  int fetches = 0;
  int tests = 0;

  @override
  Future<void> testLogin(EmailAccount account, String password) async {
    tests++;
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<List<RawEmail>> fetchSince(
    EmailAccount account,
    String password, {
    required DateTime since,
    required bool Function(String from, String subject) accept,
    int limit = 300,
  }) async {
    fetches++;
    lastSince = since;
    lastPassword = password;
    final e = error;
    if (e != null) throw e;
    return mails.where((m) => accept(m.from, m.subject)).toList();
  }
}

/// Fake SMTP port: records what would be mailed to the user's own address.
class FakeSmtp implements MailSender {
  Failure? error;
  int sent = 0;
  String? lastSubject;
  String? lastTo;
  String? lastPassword;

  /// The 6-digit code in the last subject.
  String get lastCode =>
      RegExp(r'\d{6}').firstMatch(lastSubject ?? '')!.group(0)!;

  @override
  Future<void> sendToSelf(
    EmailAccount account,
    String password, {
    required String subject,
    required String body,
  }) async {
    final e = error;
    if (e != null) throw e;
    sent++;
    lastSubject = subject;
    lastTo = account.address;
    lastPassword = password;
  }
}
