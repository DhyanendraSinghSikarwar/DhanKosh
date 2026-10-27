import 'package:enough_mail/enough_mail.dart' as em;
import 'package:hisaab/features/email_ingestion/data/enough_mail_imap_client.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';

/// [MailSender] over `enough_mail` SMTP with the user's own login (FR-03-03).
/// TLS or required STARTTLS only. Never logs.
class EnoughMailSmtpSender implements MailSender {
  /// Creates the sender; [create] is injectable for tests.
  EnoughMailSmtpSender({
    em.SmtpClient Function()? create,
    this.timeout = const Duration(seconds: 20),
  }) : _create = create ?? (() => em.SmtpClient('dhankosh'));

  final em.SmtpClient Function() _create;

  /// Connect and command timeout.
  final Duration timeout;

  @override
  Future<void> sendToSelf(
    EmailAccount account,
    String password, {
    required String subject,
    required String body,
  }) async {
    final c = _create();
    try {
      await c.connectToServer(
        account.smtpHost,
        account.smtpPort,
        isSecure: account.smtpSsl,
        timeout: timeout,
      );
      await c.ehlo();
      if (!account.smtpSsl) await c.startTls();
      await c.authenticate(account.address, password);
      final me = em.MailAddress('DhanKosh', account.address);
      await c.sendMessage(
        em.MessageBuilder.buildSimpleTextMessage(
          me,
          [em.MailAddress(null, account.address)],
          body,
          subject: subject,
        ),
      );
    } on Object catch (e) {
      throw EnoughMailImapClient.mapError(e);
    } finally {
      try {
        await c.quit();
      } on Object {
        // Already closed.
      }
    }
  }
}
