import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/verification_code.dart';

/// Connect a mailbox only after its owner types back a 6-digit code mailed
/// to the address itself (FR-03-03). Sign-in is proved with IMAP, the code is
/// sent over SMTP with the same app password; nothing else is contacted.
class VerifyEmail {
  /// Creates the use case.
  VerifyEmail({
    required ImapClient imap,
    required MailSender sender,
    required ManageEmailAccount manage,
    VerificationCode? code,
  })  : _imap = imap,
        _sender = sender,
        _manage = manage,
        _code = code ?? VerificationCode();

  final ImapClient _imap;
  final MailSender _sender;
  final ManageEmailAccount _manage;
  final VerificationCode _code;

  EmailAccount? _account;
  String? _password;

  /// Whether a code was sent and is awaited.
  bool get pending => _account != null;

  /// Signs in, then mails a code to the address. Throws `AuthFailure`,
  /// `NetworkFailure` or `TlsFailure`; the password is held in memory only
  /// until [verify] succeeds or [cancel] is called.
  Future<void> signInAndSendCode(EmailAccount account, String password) async {
    final clean = EmailAccount.cleanPassword(password);
    await _imap.testLogin(account, clean);
    _account = account;
    _password = clean;
    await _send();
  }

  /// Mails a new code (the old one stops working).
  Future<void> resend() => _send();

  Future<void> _send() async {
    final a = _account;
    final p = _password;
    if (a == null || p == null) return;
    final c = _code.issue(a.address);
    await _sender.sendToSelf(
      a,
      p,
      subject: 'DhanKosh verification code: $c',
      body: 'Your DhanKosh verification code is $c\n\n'
          'Type it into the app to finish connecting ${a.address}. '
          'It expires in 10 minutes.\n\n'
          'If you did not ask for this, change your app password and ignore '
          'this email.',
    );
  }

  /// Checks [typed]; on success saves the mailbox (password to secure
  /// storage) and clears the in-memory copy.
  Future<VerificationResult> verify(String typed) async {
    final a = _account;
    final p = _password;
    if (a == null || p == null) return VerificationResult.none;
    final r = _code.check(a.address, typed);
    if (r == VerificationResult.ok) {
      await _manage.save(a, p);
      cancel();
    }
    return r;
  }

  /// Drops the pending sign-in.
  void cancel() {
    _account = null;
    _password = null;
    _code.clear();
  }
}
