import 'package:hisaab/features/profile/domain/bank_identity.dart';

/// [identity] with an empty name, mobile or email filled from the profile
/// (FR-27-16).
BankIdentity effectiveBankIdentity(
  BankIdentity identity, {
  String? profileName,
  String? profilePhone,
  String? profileEmail,
}) =>
    BankIdentity(
      accountId: identity.accountId,
      customerId: identity.customerId,
      accountNumber: identity.accountNumber,
      ifsc: identity.ifsc,
      name: identity.name.isEmpty ? (profileName ?? '') : identity.name,
      mobile: identity.mobile.isEmpty ? (profilePhone ?? '') : identity.mobile,
      email: identity.email.isEmpty ? (profileEmail ?? '') : identity.email,
    );
