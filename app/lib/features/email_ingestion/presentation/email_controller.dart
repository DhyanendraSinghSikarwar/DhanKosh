import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/sender_whitelist.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/verification_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'email_controller.g.dart';

/// One mailbox row on the Email screen (FR-03-22, FR-03-06).
class EmailAccountView {
  /// Creates a row.
  const EmailAccountView({
    required this.account,
    this.needsReauth = false,
    this.lastReport,
  });

  /// The mailbox.
  final EmailAccount account;

  /// Sign in again.
  final bool needsReauth;

  /// Last sync result line.
  final String? lastReport;
}

/// What the Email screen shows (FR-03-22).
class EmailScreenState {
  /// Creates a state.
  const EmailScreenState({
    this.accounts = const [],
    this.customSenders = const {},
    this.defaultSenderCount = 0,
    this.busy,
    this.message,
    this.codeSentTo,
  });

  /// Saved mailboxes.
  final List<EmailAccountView> accounts;

  /// User-added senders.
  final Set<String> customSenders;

  /// Built-in senders.
  final int defaultSenderCount;

  /// `test`, `send`, `verify` or `sync` while running.
  final String? busy;

  /// Result of the last action.
  final String? message;

  /// Address a verification code was mailed to, while awaiting it.
  final String? codeSentTo;

  /// At least one saved login.
  bool get connected => accounts.isNotEmpty;

  /// Copy with new [busy] and [message].
  EmailScreenState copyWith({
    String? busy,
    String? message,
    bool clearBusy = false,
  }) =>
      EmailScreenState(
        accounts: accounts,
        customSenders: customSenders,
        defaultSenderCount: defaultSenderCount,
        busy: clearBusy ? null : (busy ?? this.busy),
        message: message,
        codeSentTo: codeSentTo,
      );
}

/// Drives the Email screen.
@riverpod
class EmailController extends _$EmailController {
  @override
  Future<EmailScreenState> build() => _load();

  Future<EmailScreenState> _load({String? message, String? codeSentTo}) async {
    final s = ref.read(emailSettingsRepositoryProvider);
    return EmailScreenState(
      accounts: [
        for (final a in await s.accounts())
          EmailAccountView(
            account: a,
            needsReauth: await s.needsReauth(a.address),
            lastReport: await s.lastReport(a.address),
          ),
      ],
      customSenders: await s.customSenders(),
      defaultSenderCount:
          SenderWhitelist(removed: await s.removedDefaultSenders())
              .defaults
              .length,
      message: message,
      codeSentTo: codeSentTo,
    );
  }

  EmailScreenState get _cur => state.value ?? const EmailScreenState();

  static String _failure(Failure f) => switch (f) {
        AuthFailure() => 'Sign-in refused. Use an app password.',
        TlsFailure() => 'Secure connection failed.',
        NetworkFailure() => 'Could not reach the mail server.',
        _ => 'Something went wrong.',
      };

  static String _resultText(VerificationResult r) => switch (r) {
        VerificationResult.ok => 'Verified.',
        VerificationResult.wrong => 'That code does not match.',
        VerificationResult.expired => 'The code expired. Tap Resend code.',
        VerificationResult.tooManyAttempts =>
          'Too many wrong tries. Tap Resend code.',
        VerificationResult.none => 'Sign in again to get a code.',
      };

  /// Signs in without saving (Test connection).
  Future<void> test(EmailAccount account, String password) async {
    final err = ManageEmailAccount.validate(account.address, password);
    if (err != null) {
      state = AsyncData(_cur.copyWith(message: err));
      return;
    }
    state = AsyncData(_cur.copyWith(busy: 'test'));
    String msg;
    try {
      await ref.read(manageEmailAccountProvider).test(account, password);
      msg = 'Connected.';
    } on Failure catch (f) {
      msg = _failure(f);
    }
    state = AsyncData(_cur.copyWith(message: msg, clearBusy: true));
  }

  /// Signs in and mails a 6-digit code to the address (FR-03-03).
  Future<void> sendCode(EmailAccount account, String password) async {
    final err = ManageEmailAccount.validate(
      account.address,
      password,
      host: account.imapHost,
    );
    if (err != null) {
      state = AsyncData(_cur.copyWith(message: err));
      return;
    }
    state = AsyncData(_cur.copyWith(busy: 'send'));
    try {
      await ref.read(verifyEmailProvider).signInAndSendCode(account, password);
      state = AsyncData(
        await _load(
          message: 'We sent a 6-digit code to ${account.address}. '
              'Check your inbox and spam.',
          codeSentTo: account.address,
        ),
      );
    } on Failure catch (f) {
      state = AsyncData(_cur.copyWith(message: _failure(f), clearBusy: true));
    }
  }

  /// Mails a new code.
  Future<void> resendCode() async {
    final to = _cur.codeSentTo;
    state = AsyncData(_cur.copyWith(busy: 'send'));
    try {
      await ref.read(verifyEmailProvider).resend();
      state = AsyncData(
        await _load(message: 'A new code is on its way.', codeSentTo: to),
      );
    } on Failure catch (f) {
      state = AsyncData(
        await _load(message: _failure(f), codeSentTo: to),
      );
    }
  }

  /// Checks the typed code; on success the mailbox is saved (FR-03-03).
  Future<void> verify(String code) async {
    final to = _cur.codeSentTo;
    final r = await ref.read(verifyEmailProvider).verify(code);
    state = AsyncData(
      await _load(
        message: _resultText(r),
        codeSentTo: r == VerificationResult.ok ? null : to,
      ),
    );
  }

  /// Drops the pending code step.
  Future<void> cancelVerify() async {
    ref.read(verifyEmailProvider).cancel();
    state = AsyncData(await _load());
  }

  /// Syncs every enabled mailbox through the shared runner.
  Future<void> syncNow() async {
    state = AsyncData(_cur.copyWith(busy: 'sync'));
    final r = await ref.read(emailSyncRunnerProvider).run();
    state = AsyncData(await _load(message: r.summary));
  }

  /// Wipes one mailbox's password and forgets it.
  Future<void> remove(String address) async {
    await ref.read(manageEmailAccountProvider).disconnect(address);
    state = AsyncData(await _load(message: 'Removed $address.'));
  }

  /// Turns a mailbox on or off for syncs (FR-03-22).
  Future<void> setEnabled(String address, {required bool enabled}) async {
    await ref
        .read(manageEmailAccountProvider)
        .setEnabled(address, enabled: enabled);
    state = AsyncData(await _load());
  }

  /// Adds a sender address or domain.
  Future<void> addSender(String input) async {
    final ok = await ref.read(manageEmailAccountProvider).addSender(input);
    state = AsyncData(
      await _load(message: ok ? null : 'Enter an address or domain.'),
    );
  }

  /// Removes a user-added sender.
  Future<void> removeSender(String sender) async {
    await ref.read(manageEmailAccountProvider).removeSender(sender);
    state = AsyncData(await _load());
  }

  /// Back to the default senders.
  Future<void> resetSenders() async {
    await ref.read(manageEmailAccountProvider).resetSenders();
    state = AsyncData(await _load(message: 'Senders reset.'));
  }
}
