/// Builds `upi://pay?...` (FR-31-12). The VPA is percent-encoded except `@`
/// and `.`; `am` is added only when [amountRupees] > 0.
String buildUpiLink({
  required String vpa,
  String payee = 'DhanKosh',
  int amountRupees = 0,
}) {
  final pa = Uri.encodeComponent(vpa).replaceAll('%40', '@');
  final am = amountRupees > 0 ? '&am=$amountRupees' : '';
  return 'upi://pay?pa=$pa&pn=${Uri.encodeComponent(payee)}&cu=INR$am';
}

/// Parses the custom amount field: digits only, at most 6 (FR-31-11); 0 when
/// empty or invalid.
int parseSupportAmount(String input) {
  if (!RegExp(r'^\d{1,6}$').hasMatch(input)) return 0;
  return int.parse(input);
}
