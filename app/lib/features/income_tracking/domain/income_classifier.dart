import 'package:parser_core/parser_core.dart';

/// Tax-input bucket of an income credit (FR-11-10).
enum IncomeBucket {
  salary,
  dividend,
  depositInterest,
  savingsInterest,
  rent,
  other,
  excluded,
}

/// Pure income text rules (memory 11 section 10).
abstract final class IncomeClassifier {
  static final _salary = RegExp('SALARY|SAL CR|PAYROLL', caseSensitive: false);
  static final _excluded = RegExp(
    'reimburs|refund|reversal|cashback',
    caseSensitive: false,
  );
  static final _dividend = RegExp(r'dividend|\bdiv\b', caseSensitive: false);
  static final _interest = RegExp(
    r'\binterest\b|\bint\.?\s?(pd|paid|cr|credit)\b|\bint\b',
    caseSensitive: false,
  );
  static final _deposit = RegExp(
    r'\bfd\b|fixed deposit|\brd\b|recurring|deposit',
    caseSensitive: false,
  );
  static final _rent = RegExp(r'\brent\b', caseSensitive: false);

  /// Category for a CREDIT message text (FR-11-02): SALARY, REFUND or INCOME.
  static Category creditCategory(String text) {
    if (_salary.hasMatch(text)) return Category.salary;
    final l = text.toLowerCase();
    if (l.contains('refund') || l.contains('revers')) return Category.refund;
    return Category.income;
  }

  /// Bucket of an INCOME/SALARY credit by merchant, note and UPI id
  /// (FR-11-10). Order: excluded, dividend, interest (deposit or savings),
  /// rent, other. Salary needs category SALARY and no excluded word.
  static IncomeBucket bucketOf({
    required Category category,
    String? merchant,
    String? note,
    String? upiId,
  }) {
    final text = [merchant, note, upiId].whereType<String>().join(' ');
    if (_excluded.hasMatch(text)) return IncomeBucket.excluded;
    if (category == Category.salary) return IncomeBucket.salary;
    if (category == Category.refund || category == Category.transfer) {
      return IncomeBucket.excluded;
    }
    if (_dividend.hasMatch(text)) return IncomeBucket.dividend;
    if (_interest.hasMatch(text)) {
      return _deposit.hasMatch(text)
          ? IncomeBucket.depositInterest
          : IncomeBucket.savingsInterest;
    }
    if (_rent.hasMatch(text)) return IncomeBucket.rent;
    return IncomeBucket.other;
  }
}
