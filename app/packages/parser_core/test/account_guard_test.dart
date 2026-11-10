// Which bank names and digits may become an account (FR-13-24).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  test('known banks only', () {
    expect(AccountGuard.isKnownBank('HDFC Bank'), isTrue);
    expect(AccountGuard.isKnownBank('SBI'), isTrue);
    expect(AccountGuard.isKnownBank('XYZBNK'), isFalse);
    expect(AccountGuard.isKnownBank('Bank'), isFalse);
    expect(AccountGuard.isKnownBank('PhonePe'), isFalse);
    expect(AccountGuard.isKnownBank('AX-HDFCBK'), isFalse);
    expect(AccountGuard.isKnownBank(null), isFalse);
  });

  test('a phone tail or placeholder digits never make an account', () {
    expect(AccountGuard.mayCreate('HDFC Bank', '1234'), isTrue);
    expect(
      AccountGuard.mayCreate('HDFC Bank', '3210', ownTails: {'3210'}),
      isFalse,
    );
    expect(AccountGuard.mayCreate('HDFC Bank', '0000'), isFalse);
    expect(AccountGuard.mayCreate('HDFC Bank', null), isFalse);
    expect(AccountGuard.mayCreate('Random Bank', '1234'), isFalse);
  });
}
