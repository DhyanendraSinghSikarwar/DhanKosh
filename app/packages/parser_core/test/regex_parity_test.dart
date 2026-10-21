// Java regex constructs the Kotlin parser relies on, checked on Dart's RegExp
// (FR-06-20, TC-06-24): named groups, look-behind, lazy quantifiers,
// case-insensitivity, `.` not crossing a newline, `$` at the end only.
import 'package:parser_core/src/text/rx.dart';
import 'package:test/test.dart';

void main() {
  test('named groups', () {
    final m = rx(r'INR\s*(?<amt>\d+)\s+(?<merchant>.+?)\.').firstMatch(
      'inr 250 SWIGGY.',
    )!;
    expect(m.namedGroup('amt'), '250');
    expect(m.namedGroup('merchant'), 'SWIGGY');
    expect(m.groupNames, containsAll(['amt', 'merchant']));
  });

  test('look-behind, positive and negative, with alternation', () {
    final avl = rx(r'(?:\b|(?<=avl)|(?<=avbl))bal\b');
    expect(avl.hasMatch('AvlBal'), isTrue);
    expect(avl.hasMatch('Avl bal'), isTrue);
    expect(avl.hasMatch('verbal'), isFalse);
    final notBe = rx(r'(?<!\bbe )(?<!\bnot )\bpaid\b');
    expect(notBe.hasMatch('has paid'), isTrue);
    expect(notBe.hasMatch('will be paid'), isFalse);
    expect(notBe.hasMatch('not paid'), isFalse);
  });

  test('variable-length look-behind used to split sentences', () {
    final re = RegExp(r'(?<!\b(?:Mr|Dr)\.)(?<=[.!?])\s+');
    expect('Paid to Dr. Rao. Done'.split(re), ['Paid to Dr. Rao.', 'Done']);
  });

  test('lazy quantifiers and case-insensitive matching', () {
    expect(rx('a.+?b').firstMatch('A1b2B')!.group(0), 'A1b');
    expect(rx(r'\bUPI\b').hasMatch('via upi'), isTrue);
  });

  test('dot does not match a newline; dollar anchors the end only', () {
    expect(rx('a.b').hasMatch('a\nb'), isFalse);
    expect(rx(r'x$').hasMatch('x\n'), isFalse);
    expect(rx(r'x$').hasMatch('abx'), isTrue);
  });

  test('allMatches from an offset keeps look-behind context', () {
    final re = rx('(?<=a)b');
    expect(findFrom(re, 'ab', 1)?.start, 1);
  });

  test('rupee sign and unicode escapes', () {
    expect(rx(r'₹\s*\d+').hasMatch('₹ 500'), isTrue);
    expect(rx('₹').hasMatch('₹'), isTrue);
  });

  test('ASCII case folding only: no match across scripts', () {
    expect(rx('k').hasMatch('K'), isFalse); // Kelvin sign
  });
}
