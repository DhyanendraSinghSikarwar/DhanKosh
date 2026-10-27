import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart'
    as app;
import 'package:hisaab/features/statement_import/domain/password_source.dart';
import 'package:parser_core/parser_core.dart' as pc;

/// Passwords to try after "no password": derived candidates (<= 240, or
/// <= 300 with bank details), then the user's saved ones; de-duplicated,
/// order kept (FR-05-09).
List<String> passwordCandidates(PasswordSource src) {
  final derived = <String>[];
  final id = src.identity;
  if (id != null) {
    final profile = _identity(id);
    // FR-27-23: further alternate names and phones count like bank details.
    final extra = pc.BankIdentity(names: id.moreNames, phones: id.morePhones);
    final hasExtra = id.moreNames.isNotEmpty || id.morePhones.isNotEmpty;
    derived.addAll(
      src.hasBankDetails || hasExtra
          ? pc.PasswordGuesser.forBanks(
              profile,
              [
                if (hasExtra) extra,
                for (final b in src.banks)
                  pc.BankIdentity(
                    customerId: b.customerId,
                    accountNumber: b.accountNumber,
                    ifsc: b.ifsc,
                    names: [if (b.name.isNotEmpty) b.name],
                    phones: [if (b.mobile.isNotEmpty) b.mobile],
                    emails: [if (b.email.isNotEmpty) b.email],
                  ),
              ],
              last4s: src.cardLast4s,
            )
          : pc.PasswordGuesser.candidates(profile, src.cardLast4s),
    );
  }
  return {...derived, ...src.saved}.toList();
}

pc.Identity _identity(app.Identity i) {
  final d = i.dob;
  return pc.Identity(
    name: i.name,
    dob: d == null ? null : pc.CivilDate(d.year, d.month, d.day),
    pan: i.pan,
    phone: i.phone,
    altName: i.altName,
    altPhone: i.altPhone,
    email: i.email,
  );
}
