import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/sender_providers.dart';
import 'package:hisaab/features/email_ingestion/domain/sender_whitelist.dart';
import 'package:hisaab/features/sms_ingestion/domain/sender_overrides.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sender_lists_controller.g.dart';

/// The two editable lists (FR-26-31): SMS bank sender ids and mail domains.
class SenderListsState {
  /// Creates a state.
  const SenderListsState({
    required this.smsDefaults,
    required this.mailDefaults,
    required this.sms,
    required this.mailAdded,
    required this.mailRemoved,
  });

  /// Built-in SMS sender ids, sorted.
  final List<String> smsDefaults;

  /// Built-in mail domains and addresses, sorted.
  final List<String> mailDefaults;

  /// User edits of the SMS list.
  final SenderOverrides sms;

  /// Mail senders the user added.
  final Set<String> mailAdded;

  /// Built-in mail senders switched off.
  final Set<String> mailRemoved;
}

/// Edits the SMS sender list and the mail-domain list.
@riverpod
class SenderListsController extends _$SenderListsController {
  @override
  Future<SenderListsState> build() async {
    final mail = ref.read(emailSettingsRepositoryProvider);
    return SenderListsState(
      smsDefaults: defaultSenderKeys().sms,
      mailDefaults: SenderWhitelist.standardDefaults().toList()..sort(),
      sms: await ref.read(senderOverridesStoreProvider).read(),
      mailAdded: await mail.customSenders(),
      mailRemoved: await mail.removedDefaultSenders(),
    );
  }

  SenderListsState get _s => state.requireValue;

  Future<void> _saveSms(SenderOverrides o) async {
    await ref.read(senderOverridesCacheProvider).save(o);
    state = AsyncData(
      SenderListsState(
        smsDefaults: _s.smsDefaults,
        mailDefaults: _s.mailDefaults,
        sms: o,
        mailAdded: _s.mailAdded,
        mailRemoved: _s.mailRemoved,
      ),
    );
  }

  /// Adds an SMS sender id; false when [input] is not one.
  Future<bool> addSms(String input) async {
    final k = SenderOverrides.normalize(input);
    if (k == null || k.contains('.')) return false;
    await _saveSms(
      _s.sms.copyWith(
        added: {..._s.sms.added, k},
        removed: {..._s.sms.removed}..remove(k),
      ),
    );
    return true;
  }

  /// Removes a user-added SMS sender.
  Future<void> removeAddedSms(String key) => _saveSms(
        _s.sms.copyWith(added: {..._s.sms.added}..remove(key)),
      );

  /// Switches a built-in SMS sender on or off.
  Future<void> setSmsDefault(String key, {required bool on}) => _saveSms(
        _s.sms.copyWith(
          removed: on
              ? ({..._s.sms.removed}..remove(key))
              : {..._s.sms.removed, key},
        ),
      );

  /// Back to the built-in SMS list.
  Future<void> resetSms() => _saveSms(SenderOverrides.none);

  Future<void> _reloadMail() async {
    final mail = ref.read(emailSettingsRepositoryProvider);
    state = AsyncData(
      SenderListsState(
        smsDefaults: _s.smsDefaults,
        mailDefaults: _s.mailDefaults,
        sms: _s.sms,
        mailAdded: await mail.customSenders(),
        mailRemoved: await mail.removedDefaultSenders(),
      ),
    );
  }

  /// Adds a mail address or domain; false when it is not valid. Mail is read
  /// again from the saved window (FR-03-12).
  Future<bool> addMail(String input) async {
    final k = SenderWhitelist.normalize(input);
    if (k == null) return false;
    await ref
        .read(emailSettingsRepositoryProvider)
        .saveCustomSenders({..._s.mailAdded, k});
    await _reloadMail();
    return true;
  }

  /// Removes a user-added mail sender.
  Future<void> removeAddedMail(String key) async {
    await ref
        .read(emailSettingsRepositoryProvider)
        .saveCustomSenders({..._s.mailAdded}..remove(key));
    await _reloadMail();
  }

  /// Switches a built-in mail sender on or off.
  Future<void> setMailDefault(String key, {required bool on}) async {
    await ref.read(emailSettingsRepositoryProvider).saveRemovedDefaultSenders(
          on ? ({..._s.mailRemoved}..remove(key)) : {..._s.mailRemoved, key},
        );
    await _reloadMail();
  }

  /// Back to the built-in mail list.
  Future<void> resetMail() async {
    final repo = ref.read(emailSettingsRepositoryProvider);
    await repo.saveRemovedDefaultSenders(const {});
    await repo.saveCustomSenders(const {});
    await _reloadMail();
  }
}
