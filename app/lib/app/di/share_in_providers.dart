import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/security_privacy/data/channel_screen_guard.dart';
import 'package:hisaab/features/security_privacy/domain/screen_guard.dart';
import 'package:hisaab/features/statement_import/data/channel_shared_file_source.dart';
import 'package:hisaab/features/statement_import/domain/shared_file_source.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

/// Files shared into the app (F-05).
final sharedFileSourceProvider = Provider<SharedFileSource>(
  (ref) => const ChannelSharedFileSource(),
);

/// Screenshot blocking (F-25).
final screenGuardProvider = Provider<ScreenGuard>(
  (ref) => const ChannelScreenGuard(),
);

/// A shared file waiting for the Statements screen to import it. Set only
/// after the app is unlocked (FR-05-27).
class SharedInbox extends Notifier<PickedFile?> {
  @override
  PickedFile? build() => null;

  /// Puts [file] in the inbox.
  // ignore: use_setters_to_change_properties
  void put(PickedFile file) => state = file;

  /// Takes the file out, leaving the inbox empty.
  PickedFile? take() {
    final f = state;
    state = null;
    return f;
  }
}

/// The shared-file inbox.
final sharedInboxProvider =
    NotifierProvider<SharedInbox, PickedFile?>(SharedInbox.new);
