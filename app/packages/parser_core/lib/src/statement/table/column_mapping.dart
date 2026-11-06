import 'package:parser_core/parser_core.dart' show StatementDateFormats;
import 'package:parser_core/src/statement/table/statement_cells.dart'
    show StatementDateFormats;

/// Which spreadsheet column holds what (FR-05-28). All fields are optional so
/// a saved layout from an older version still loads. A mapping is usable when
/// it has a date and either one amount column or a debit and/or credit one.
class ColumnMapping {
  /// Creates a mapping. Columns are zero-based; null means "none".
  const ColumnMapping({
    this.headerRow = 0,
    this.date,
    this.dateFormat,
    this.description,
    this.amount,
    this.type,
    this.debit,
    this.credit,
    this.balance,
    this.reference,
  });

  /// Reads a mapping saved by [toJson]; unknown or missing keys are ignored.
  factory ColumnMapping.fromJson(Map<String, Object?> j) {
    int? i(String k) => j[k] is int ? j[k]! as int : null;
    return ColumnMapping(
      headerRow: i('headerRow') ?? 0,
      date: i('date'),
      dateFormat: j['dateFormat'] is String ? j['dateFormat']! as String : null,
      description: i('description'),
      amount: i('amount'),
      type: i('type'),
      debit: i('debit'),
      credit: i('credit'),
      balance: i('balance'),
      reference: i('reference'),
    );
  }

  /// Row holding the column names; rows above it are the preamble.
  final int headerRow;

  /// Transaction date column.
  final int? date;

  /// A date pattern name from [StatementDateFormats], or null for automatic.
  final String? dateFormat;

  /// Narration, particulars or description column.
  final int? description;

  /// One signed amount column (single mode).
  final int? amount;

  /// A Dr/Cr direction column (single mode).
  final int? type;

  /// Withdrawal column (split mode).
  final int? debit;

  /// Deposit column (split mode).
  final int? credit;

  /// Running balance column.
  final int? balance;

  /// Reference, UTR or cheque number column.
  final int? reference;

  /// Separate debit and credit columns rather than one amount column.
  bool get isSplit => amount == null && (debit != null || credit != null);

  /// A date and an amount to read.
  bool get isComplete => date != null && (amount != null || isSplit);

  /// A copy with the given fields replaced. Pass the `clear*` flags to set a
  /// column back to "none".
  ColumnMapping copyWith({
    int? headerRow,
    int? date,
    String? dateFormat,
    int? description,
    int? amount,
    int? type,
    int? debit,
    int? credit,
    int? balance,
    int? reference,
    bool clearDate = false,
    bool clearDateFormat = false,
    bool clearDescription = false,
    bool clearAmount = false,
    bool clearType = false,
    bool clearDebit = false,
    bool clearCredit = false,
    bool clearBalance = false,
    bool clearReference = false,
  }) =>
      ColumnMapping(
        headerRow: headerRow ?? this.headerRow,
        date: clearDate ? null : (date ?? this.date),
        dateFormat: clearDateFormat ? null : (dateFormat ?? this.dateFormat),
        description:
            clearDescription ? null : (description ?? this.description),
        amount: clearAmount ? null : (amount ?? this.amount),
        type: clearType ? null : (type ?? this.type),
        debit: clearDebit ? null : (debit ?? this.debit),
        credit: clearCredit ? null : (credit ?? this.credit),
        balance: clearBalance ? null : (balance ?? this.balance),
        reference: clearReference ? null : (reference ?? this.reference),
      );

  /// A map to store.
  Map<String, Object?> toJson() => {
        'headerRow': headerRow,
        'date': date,
        'dateFormat': dateFormat,
        'description': description,
        'amount': amount,
        'type': type,
        'debit': debit,
        'credit': credit,
        'balance': balance,
        'reference': reference,
      };

  @override
  bool operator ==(Object other) =>
      other is ColumnMapping &&
      other.headerRow == headerRow &&
      other.date == date &&
      other.dateFormat == dateFormat &&
      other.description == description &&
      other.amount == amount &&
      other.type == type &&
      other.debit == debit &&
      other.credit == credit &&
      other.balance == balance &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(
        headerRow,
        date,
        dateFormat,
        description,
        amount,
        type,
        debit,
        credit,
        balance,
        reference,
      );

  @override
  String toString() => 'ColumnMapping(${toJson()})';
}
