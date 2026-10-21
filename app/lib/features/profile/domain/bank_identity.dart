/// Per-account unlock details, kept sealed (FR-27-13, memory 05 FR-10).
class BankIdentity {
  /// Creates details for [accountId]; empty strings mean "not set".
  const BankIdentity({
    required this.accountId,
    this.customerId = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.name = '',
    this.mobile = '',
    this.email = '',
  });

  /// Reads the stored JSON map.
  factory BankIdentity.fromJson(int accountId, Map<String, Object?> j) =>
      BankIdentity(
        accountId: accountId,
        customerId: (j['customerId'] as String?) ?? '',
        accountNumber: (j['accountNumber'] as String?) ?? '',
        ifsc: (j['ifsc'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        mobile: (j['mobile'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
      );

  /// Owning account id.
  final int accountId;

  /// At most 20 alphanumerics.
  final String customerId;

  /// At most 24 characters.
  final String accountNumber;

  /// At most 11 characters, upper case.
  final String ifsc;
  final String name;
  final String mobile;
  final String email;

  /// True when nothing is set.
  bool get isEmpty =>
      customerId.isEmpty &&
      accountNumber.isEmpty &&
      ifsc.isEmpty &&
      name.isEmpty &&
      mobile.isEmpty &&
      email.isEmpty;

  /// Applies the field limits of memory 05 section 10.
  BankIdentity normalised() => BankIdentity(
        accountId: accountId,
        customerId: _cap(customerId.replaceAll(RegExp('[^A-Za-z0-9]'), ''), 20),
        accountNumber: _cap(accountNumber.trim(), 24),
        ifsc: _cap(ifsc.trim().toUpperCase(), 11),
        name: name.trim(),
        mobile: mobile.trim(),
        email: email.trim(),
      );

  /// JSON map stored in the sealed blob.
  Map<String, Object?> toJson() => {
        'customerId': customerId,
        'accountNumber': accountNumber,
        'ifsc': ifsc,
        'name': name,
        'mobile': mobile,
        'email': email,
      };

  static String _cap(String s, int n) => s.length > n ? s.substring(0, n) : s;
}
