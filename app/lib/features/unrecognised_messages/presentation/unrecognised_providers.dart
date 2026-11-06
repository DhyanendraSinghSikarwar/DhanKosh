// Riverpod's autoDispose provider types are not worth spelling out.
// ignore_for_file: specify_nonobvious_property_types
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/unrecognised_providers.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';

/// Messages waiting for the user, newest first (FR-38-04).
final freshMessagesProvider =
    StreamProvider.autoDispose<List<UnrecognisedMessage>>(
  (ref) => ref.watch(unrecognisedRepositoryProvider).watchFresh(),
);

/// How many wait.
final freshCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(unrecognisedRepositoryProvider).watchFreshCount(),
);

/// Learned and ignored senders (FR-38-07, FR-38-08).
final senderPrefsProvider = StreamProvider.autoDispose<List<SenderPref>>(
  (ref) => ref.watch(unrecognisedRepositoryProvider).watchPrefs(),
);
