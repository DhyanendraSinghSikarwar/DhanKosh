import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/sender_whitelist.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'email_controller.g.dart';

/// What the Email screen shows (FR-03-22).
class EmailScreenState {
  /// Creates a state.
  const EmailScreenState({
    this.account,
    this.needsReauth = false,
    this.lastReport,
    this.customSenders = const {},
    this.defaultSenderCount = 0,
    this.busy,
    this.message,
  });

  /// Saved account, or null.
  final EmailAccount? account;

  /// Sign in again.
  final bool needsReauth;

  /// Last sync result line.
  final String? lastReport;

  /// User-added senders.
  final Set<String> customSenders;

  /// Built-in senders.
  final int defaultSenderCount;

  /// `test`, `save` or `sync` while running.
  final String? busy;

  /// Result of the last action.
  final String? message;

  /// Connected with a saved login.
  bool get connected => account != null;

  /// Copy with new [busy] and [message].
  EmailScreenState copyWith({
    String? busy,
    String? message,
    bool clearBusy = false,
  }) =>
      EmailScreenState(
        account: account,
        needsReauth: needsReauth,
        lastReport: lastReport,
        customSenders: customSenders,
        defaultSenderCount: defaultSenderCount,
        busy: clearBusy ? null : (busy ?? this.busy),
        message: message,
      );
}

/// Drives the Email screen.
@riverpod
class EmailController extends _$EmailController {
  @override
  Future<EmailScreenState> build() => _load();

  Future<EmailScreenState> _load({String? message}) async {
    final s = ref.read(emailSettingsRepositoryProvider);
    return EmailScreenState(
      account: await s.account(),
      needsReauth: await s.needsReauth(),
      lastReport: await s.lastReport(),
      customSenders: await s.customSenders(),
      defaultSenderCount: SenderWhitelist().defaults.length,
      message: message,
    );
  }

  EmailScreenState get _cur => state.value ?? const EmailScreenState();

  static String _failure(Failure f) => switch (f) {
        AuthFailure() => 'Sign-in refused. Use an app password.',
        TlsFailure() => 'Secure connection failed.',
        NetworkFailure() => 'Could not reach the mail server.',
        _ => 'Something went wrong.',
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

  /// Saves the login (password to secure storage only).
  Future<void> save(EmailAccount account, String password) async {
    final err = ManageEmailAccount.validate(
      account.address,
      password,
      host: account.imapHost,
    );
    if (err != null) {
      state = AsyncData(_cur.copyWith(message: err));
      return;
    }
    state = AsyncData(_cur.copyWith(busy: 'save'));
    await ref.read(manageEmailAccountProvider).save(account, password);
    state = AsyncData(await _load(message: 'Saved.'));
  }

  /// Syncs now through the shared runner.
  Future<void> syncNow() async {
    state = AsyncData(_cur.copyWith(busy: 'sync'));
    final r = await ref.read(emailSyncRunnerProvider).run();
    state = AsyncData(await _load(message: r.summary));
  }

  /// Wipes the password and forgets the account.
  Future<void> disconnect() async {
    await ref.read(manageEmailAccountProvider).disconnect();
    state = AsyncData(await _load(message: 'Disconnected.'));
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
