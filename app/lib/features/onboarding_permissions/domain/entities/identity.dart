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
    this.moreNames = const [],
    this.morePhones = const [],
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
        moreNames: [...(j['moreNames'] as List? ?? const []).cast<String>()],
        morePhones: [...(j['morePhones'] as List? ?? const []).cast<String>()],
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

  /// Further alternate names after [altName] (FR-27-23).
  final List<String> moreNames;

  /// Further alternate phones after [altPhone] (FR-27-23).
  final List<String> morePhones;

  /// Every alternate name, primary first.
  List<String> get allAltNames => [
        if (altName != null && altName!.isNotEmpty) altName!,
        ...moreNames,
      ];

  /// Every alternate phone, primary first.
  List<String> get allAltPhones => [
        if (altPhone != null && altPhone!.isNotEmpty) altPhone!,
        ...morePhones,
      ];

  /// ISO-date JSON map.
  Map<String, Object?> toJson() => {
        'name': name,
        'dob': dob?.toIso8601String().substring(0, 10),
        'pan': pan,
        'phone': phone,
        'altName': altName,
        'altPhone': altPhone,
        'email': email,
        'moreNames': moreNames,
        'morePhones': morePhones,
      };
}
