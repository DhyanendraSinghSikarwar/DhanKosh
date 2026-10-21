// Statement password candidates. Port of PasswordGuesserTest and
// BankIdentityGuessTest (FR-05-09, TC-05-09).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  const me = Identity(
    name: 'Asha Kumari Verma',
    dob: CivilDate(1994, 3, 7),
    pan: 'abcpv1234k',
    phone: '+91 98765 43210',
  );
  final guesses = PasswordGuesser.candidates(me, ['2779']);
  final withAlts =
      me.copyWith(altName: 'Aasha Sharma', altPhone: '91234 56780');
  final altGuesses = PasswordGuesser.candidates(withAlts, ['2779']);

  test('common statement formats are guessed', () {
    for (final p in [
      'ABCPV1234K', 'ASHA0703', 'asha0703', '07031994', '070319942779', //
      '0703', '9876543210', 'VERM0703',
    ]) {
      expect(guesses, contains(p));
    }
  });

  test('the PAN comes first, for CAS statements', () {
    expect(guesses.first, 'ABCPV1234K');
  });

  test('the list stays small enough to try on every PDF', () {
    expect(guesses.length, lessThan(120));
  });

  test('alternates default to none', () {
    expect(me.altName, isNull);
    expect(me.altPhone, isNull);
  });

  test('alternate name patterns are guessed', () {
    for (final p in [
      'AASH0703', 'aash070394', 'SHAR0703', 'Shar07031994', 'SHAR2779', //
      'SHAR3210',
    ]) {
      expect(altGuesses, contains(p));
    }
  });

  test('alternate mobile patterns are guessed', () {
    for (final p in [
      '9123456780', '6780', '56780', 'ASHA6780', 'VERM6780', 'SHAR6780', //
      '67800703', '07036780',
    ]) {
      expect(altGuesses, contains(p));
    }
  });

  test('the primary name and mobile are tried before the alternates', () {
    expect(
      altGuesses.indexOf('ASHA0703'),
      lessThan(altGuesses.indexOf('SHAR0703')),
    );
    expect(
      altGuesses.indexOf('9876543210'),
      lessThan(altGuesses.indexOf('9123456780')),
    );
    expect(altGuesses.first, 'ABCPV1234K');
  });

  test('adding alternates keeps every primary guess', () {
    expect(altGuesses, containsAll(guesses));
  });

  test('alternates and many cards still stay bounded', () {
    final cards = [for (var i = 1000; i <= 1011; i++) '$i'];
    final many = PasswordGuesser.candidates(withAlts, cards);
    expect(many.length, lessThan(250));
    expect(altGuesses.length, lessThan(250));
    expect(many, contains('ASHA0703'));
  });

  test('a blank identity yields nothing', () {
    expect(PasswordGuesser.candidates(const Identity()), isEmpty);
  });

  test('TC-05-09: the documented identity gives the documented candidates', () {
    const id = Identity(
      name: 'Asha Rao',
      dob: CivilDate(1990, 5, 14),
      pan: 'ABCDE1234F',
      phone: '9812345610',
    );
    final c = PasswordGuesser.candidates(id, ['1234']);
    for (final p in [
      'ABCDE1234F', 'ASHA1405', 'asha1405', 'Asha14051990', '140519901234', //
      '14051990', '1405', '9812345610', '5610', '45610', '345610',
    ]) {
      expect(c, contains(p));
    }
    expect(c.length, lessThanOrEqualTo(PasswordGuesser.max));
    expect(c.every((p) => p.length >= 4), isTrue);
  });

  // Bank identities.

  const profile = Identity(
    name: 'Asha Kumari Verma',
    dob: CivilDate(1994, 3, 7),
    pan: 'abcpv1234k',
    phone: '+91 98765 43210',
  );
  const hdfc = BankIdentity(
    customerId: '12345678',
    accountNumber: '50100234567891',
    ifsc: 'HDFC0001234',
  );

  test('the customer id comes first for an HDFC-like identity', () {
    final g = PasswordGuesser.forBanks(profile, [hdfc], last4s: ['2779']);
    expect(g.first, '12345678');
  });

  test('account number variants and the IFSC are guessed', () {
    final g = PasswordGuesser.forBanks(profile, [hdfc]);
    for (final p in [
      '50100234567891', '7891', '67891', '567891', '34567891', 'HDFC0001234', //
      'hdfc0001234',
    ]) {
      expect(g, contains(p));
    }
    expect(g.indexOf('34567891'), lessThan(g.indexOf('ABCPV1234K')));
  });

  test('an account name beats the profile name', () {
    final b = hdfc.copyWith(names: ['Ria Mehta']);
    final g = PasswordGuesser.forBanks(profile, [b]);
    expect(g.indexOf('RIA0703'), isNonNegative);
    expect(g.indexOf('RIA0703'), lessThan(g.indexOf('ASHA0703')));
    expect(g, contains('ASHA0703'));
  });

  test('an account mobile beats the profile mobile', () {
    final g = PasswordGuesser.forBanks(
      profile,
      [
        hdfc.copyWith(phones: ['91234 56780']),
      ],
    );
    expect(g.indexOf('9123456780'), lessThan(g.indexOf('9876543210')));
  });

  test('without combos only exact forms and the profile are tried', () {
    final b = hdfc.copyWith(names: ['Ria Mehta']);
    final g = PasswordGuesser.forBanks(profile, [b], combos: false);
    expect(g, isNot(contains('RIA0703')));
    expect(g.first, '12345678');
  });

  test('the list is bounded and has no duplicates', () {
    final many = [
      for (var i = 1; i <= 12; i++)
        hdfc.copyWith(
          customerId: '9000000$i',
          accountNumber: '5010000000$i$i',
          names: ['Name$i Surname'],
        ),
    ];
    final g = PasswordGuesser.forBanks(
      profile.copyWith(altName: 'Aasha Sharma', altPhone: '91234 56780'),
      many,
      last4s: [for (var i = 1000; i <= 1011; i++) '$i'],
    );
    expect(g.length, lessThanOrEqualTo(PasswordGuesser.maxWithBanks));
    expect(g.length, g.toSet().length);
  });

  test('the identity API is the same with no bank details', () {
    expect(
      PasswordGuesser.candidates(profile, ['2779']),
      PasswordGuesser.forBanks(profile, [], last4s: ['2779']),
    );
    expect(profile.email, isNull);
  });

  test('bank keys match names and senders', () {
    expect(BankKeys.of('HDFC Bank'), 'hdfc');
    expect(BankKeys.of('HDFC <emailstatements.cards@hdfcbank.net>'), 'hdfc');
    expect(BankKeys.of('SBI Card'), 'sbi');
    expect(BankKeys.of('Some Fund'), isNull);
  });
}
