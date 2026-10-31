import 'package:flutter/services.dart';

/// Keeps an Indian mobile field to its 10 digits: strips spaces and dashes and
/// drops a pasted `+91` or leading `0`, instead of cutting the tail.
class PhoneDigitsFormatter extends TextInputFormatter {
  /// Creates the formatter.
  const PhoneDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 10 && d.startsWith('91')) {
      d = d.substring(2);
    } else if (d.length > 10 && d.startsWith('0')) {
      d = d.substring(1);
    }
    if (d.length > 10) d = d.substring(0, 10);
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}
