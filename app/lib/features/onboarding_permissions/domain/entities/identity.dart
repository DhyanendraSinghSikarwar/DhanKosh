/// Sealed identity used to guess statement passwords (FR-01-07).
class Identity {
  /// Creates an identity.
  const Identity({
    required this.name,
    this.dob,
    this.pan,
    this.phone,
    this.altName,
    this.altPhone,
    this.email,
  });

  /// Parses [toJson] output.
  factory Identity.fromJson(Map<String, Object?> j) => Identity(
        name: j['name']! as String,
        dob: j['dob'] == null ? null : DateTime.parse(j['dob']! as String),
        pan: j['pan'] as String?,
        phone: j['phone'] as String?,
        altName: j['altName'] as String?,
        altPhone: j['altPhone'] as String?,
        email: j['email'] as String?,
      );

  /// Full name as per bank.
  final String name;

  /// Date of birth.
  final DateTime? dob;

  /// PAN, `[A-Z]{5}[0-9]{4}[A-Z]`.
  final String? pan;

  /// `+91 NNNNNNNNNN`.
  final String? phone;

  /// Alternate name.
  final String? altName;

  /// Alternate phone, `+91 NNNNNNNNNN`.
  final String? altPhone;

  /// Stored, not used for password guesses.
  final String? email;

  /// ISO-date JSON map.
  Map<String, Object?> toJson() => {
        'name': name,
        'dob': dob?.toIso8601String().substring(0, 10),
        'pan': pan,
        'phone': phone,
        'altName': altName,
        'altPhone': altPhone,
        'email': email,
      };
}
