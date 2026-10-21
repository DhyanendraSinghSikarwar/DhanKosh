/// Plain (non-sealed) profile.
class UserProfile {
  /// Creates a profile.
  const UserProfile({
    this.name,
    this.email,
    this.phone,
    this.occupation,
    this.photoPath,
  });

  /// Display name.
  final String? name;

  /// Profile email.
  final String? email;

  /// `+91 NNNNNNNNNN`.
  final String? phone;

  /// Occupation.
  final String? occupation;

  /// Absolute photo path.
  final String? photoPath;
}
