import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/profile/domain/bank_identity.dart';
import 'package:hisaab/features/profile/domain/effective_bank_identity.dart';

/// Everything the password guesser needs (memory 05 section 2.4, memory 27
/// section 3.5). Candidate generation itself is a pure parser function.
class PasswordSource {
  /// Creates a source.
  const PasswordSource({
    required this.identity,
    required this.cardLast4s,
    required this.banks,
    required this.saved,
  });

  /// The user's identity; null before details were saved.
  final Identity? identity;

  /// Last four digits of known cards and accounts, de-duplicated.
  final Set<String> cardLast4s;

  /// Per-account details with the profile fallback applied (FR-27-16).
  final List<BankIdentity> banks;

  /// User-saved passwords, tried last (FR-05-09).
  final List<String> saved;

  /// True when per-bank details exist, so the cap is 300 not 240.
  bool get hasBankDetails => banks.isNotEmpty;
}

/// Builds a [PasswordSource] from stored data (pure; FR-05-09, FR-27-16).
PasswordSource assemblePasswordSource({
  required Identity? identity,
  required UserProfile profile,
  required Iterable<String> cardLast4s,
  required Iterable<BankIdentity> banks,
  required Iterable<String> saved,
}) =>
    PasswordSource(
      identity: identity,
      cardLast4s: {
        for (final l in cardLast4s)
          if (l.length == 4) l,
      },
      banks: [
        for (final b in banks)
          if (!b.isEmpty)
            effectiveBankIdentity(
              b,
              profileName: identity?.name ?? profile.name,
              profilePhone: profile.phone,
              profileEmail: profile.email,
            ),
      ],
      saved: [
        for (final s in saved)
          if (s.isNotEmpty) s,
      ],
    );
