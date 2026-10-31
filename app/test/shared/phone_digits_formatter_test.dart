import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/shared/widgets/phone_digits_formatter.dart';

void main() {
  const f = PhoneDigitsFormatter();
  String run(String text) => f
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
      .text;

  test('keeps 10 digits and drops a pasted +91 or leading 0', () {
    expect(run('9876543210'), '9876543210');
    expect(run('+91 98765 43210'), '9876543210');
    expect(run('09876543210'), '9876543210');
    expect(run('98765-4321099'), '9876543210');
  });
}
