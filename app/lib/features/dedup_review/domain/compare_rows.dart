import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

/// One compared field of two rows (FR-07-11).
class FieldDiff {
  /// Creates a field comparison.
  const FieldDiff(this.label, this.newValue, this.existingValue);

  final String label;
  final String newValue;
  final String existingValue;

  /// True when the two sides differ.
  bool get differs => newValue != existingValue;
}

/// Compares a flagged row with the row it may repeat, field by field.
/// [money] formats paise; [when] formats epoch ms. A missing value is "-".
List<FieldDiff> compareRows(
  LedgerTx fresh,
  LedgerTx existing, {
  required String Function(int minor, String currency) money,
  required String Function(int ms) when,
}) {
  String v(String? s) => s == null || s.isEmpty ? '-' : s;
  FieldDiff d(String l, String? a, String? b) => FieldDiff(l, v(a), v(b));
  return [
    d(
      'Amount',
      money(fresh.amountMinor, fresh.currency),
      money(existing.amountMinor, existing.currency),
    ),
    d('Type', fresh.type.name, existing.type.name),
    d('Time', when(fresh.timestamp), when(existing.timestamp)),
    d('Merchant', fresh.merchant, existing.merchant),
    d('Bank', fresh.bankName, existing.bankName),
    d('Account', fresh.accountLast4, existing.accountLast4),
    d('Reference', fresh.referenceNumber, existing.referenceNumber),
    d('UPI id', fresh.upiId, existing.upiId),
    d('Category', fresh.category.label, existing.category.label),
    d('Channel', fresh.channel.name, existing.channel.name),
  ];
}
