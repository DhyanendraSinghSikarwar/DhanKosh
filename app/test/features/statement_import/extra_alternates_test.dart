import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/statement_import/domain/password_candidates.dart';
import 'package:hisaab/features/statement_import/domain/password_source.dart';

void main() {
  // FR-27-23: every alternate name and mobile feeds the guesses.
  test('further alternates add password candidates', () {
    PasswordSource src(Identity id) => PasswordSource(
          identity: id,
          cardLast4s: const {},
          banks: const [],
          saved: const [],
        );
    const one = Identity(
      name: 'Asha Demo',
      phone: '+91 9876543210',
      altName: 'A Demo',
    );
    const many = Identity(
      name: 'Asha Demo',
      phone: '+91 9876543210',
      altName: 'A Demo',
      moreNames: ['Asha Zed'],
      morePhones: ['+91 9123456780'],
    );
    final base = passwordCandidates(src(one));
    final more = passwordCandidates(src(many));
    expect(more.length, greaterThan(base.length));
    expect(more.any((p) => p.contains('9123456780'.substring(6))), isTrue);
    expect(Identity.fromJson(many.toJson()).moreNames, ['Asha Zed']);
    expect(many.allAltNames, ['A Demo', 'Asha Zed']);
    expect(many.allAltPhones, ['+91 9123456780']);
  });
}
