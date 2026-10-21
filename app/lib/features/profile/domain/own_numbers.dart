/// Last four digits of the user's own numbers (FR-27-17). Numbers need at
/// least 10 digits; they are passed to the ledger so they never become
/// accounts.
Set<String> ownLast4s(Iterable<String?> numbers) {
  final out = <String>{};
  for (final n in numbers) {
    final digits = (n ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) out.add(digits.substring(digits.length - 4));
  }
  return out;
}
