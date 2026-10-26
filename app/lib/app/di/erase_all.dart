import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';

/// Erases everything the app stores on this phone (FR-25-26): the database,
/// saved statement passwords, bank identity details and the mailbox password.
/// Cursors and caches live in the database and go with it.
Future<void> eraseAllData(WidgetRef ref) async {
  await ref.read(dataResetRepositoryProvider).eraseAll();
  final passwords = ref.read(savedPasswordRepositoryProvider);
  for (final p in await passwords.list()) {
    await passwords.remove(p.label);
  }
  final identities = ref.read(bankIdentityRepositoryProvider);
  for (final i in await identities.readAll()) {
    await identities.remove(i.accountId);
  }
  await ref.read(emailCredentialStoreProvider).wipe();
}
