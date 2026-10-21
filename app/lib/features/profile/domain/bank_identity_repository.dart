import 'package:hisaab/features/profile/domain/bank_identity.dart';

/// Sealed per-account unlock details (FR-27-13, FR-27-15).
abstract interface class BankIdentityRepository {
  /// Details of [accountId], or null.
  Future<BankIdentity?> read(int accountId);

  /// Every saved detail set.
  Future<List<BankIdentity>> readAll();

  /// Saves [identity]; an empty one removes the entry.
  Future<void> save(BankIdentity identity);

  /// Removes the details of [accountId].
  Future<void> remove(int accountId);
}
