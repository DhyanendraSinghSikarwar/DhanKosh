import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';

/// Fake IMAP: serves [mails] through the real accept filter, or throws
/// [error]. Records what it was asked.
class FakeImap implements ImapClient {
  FakeImap([this.mails = const []]);

  List<RawEmail> mails;
  Object? error;
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
