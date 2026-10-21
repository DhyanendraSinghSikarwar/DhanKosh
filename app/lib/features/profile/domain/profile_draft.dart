import 'package:hisaab/features/onboarding_permissions/domain/validators/onboarding_validators.dart';

/// Edit state of the Profile screen (FR-27-07, FR-27-08).
class ProfileDraft {
  /// Creates a draft.
  const ProfileDraft({
    required this.name,
    required this.pan,
    required this.dirty,
  });

  final String name;
  final String pan;

  /// True once any field differs from the saved values.
  final bool dirty;

  /// Name is required.
  bool get nameValid => name.trim().isNotEmpty;

  /// PAN blank or `[A-Z]{5}[0-9]{4}[A-Z]`.
  bool get panValid => OnboardingValidators.isValidPanOrBlank(pan);

  /// Save needs a change and valid entries.
  bool get canSave => dirty && nameValid && panValid;
}
