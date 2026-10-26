import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// What an investment ledger row is (FR-16-25).
enum InvestmentTxKind {
  buy('Buy'),
  redemption('Redemption'),
  dividend('Dividend');

  const InvestmentTxKind(this.label);

  /// Display name.
  final String label;
}

final _div = RegExp('dividend|idcw|interest', caseSensitive: false);
final _redeem = RegExp('redeem|redemption|sell|sold', caseSensitive: false);

/// True for rows in the Portfolio investment list: INVESTMENT rows and
/// credits in the investment category (FR-16-25).
bool isInvestmentTx(LedgerTx t) =>
    !t.needsReview &&
    t.duplicateOfId == null &&
    (t.type == TransactionType.investment ||
        (t.type == TransactionType.credit &&
            t.category == Category.investment));

/// Buy, redemption or dividend (FR-16-25): INVESTMENT rows are buys unless
/// the text says redeem; credits are dividends when the text says so, else
/// redemptions.
InvestmentTxKind investmentKind(LedgerTx t) {
  final text = '${t.merchant ?? ''} ${t.note ?? ''}';
  if (t.type == TransactionType.credit) {
    return _div.hasMatch(text)
        ? InvestmentTxKind.dividend
        : InvestmentTxKind.redemption;
  }
  return _redeem.hasMatch(text)
      ? InvestmentTxKind.redemption
      : InvestmentTxKind.buy;
}
