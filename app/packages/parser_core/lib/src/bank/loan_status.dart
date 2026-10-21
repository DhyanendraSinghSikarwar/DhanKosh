import 'package:parser_core/src/util/civil.dart';

/// A bank deposit account: fixed, recurring, or a Public Provident Fund
/// account.
enum DepositKind { fd, rd, ppf }

/// What the bank does when a deposit matures.
enum DepositAction { payout, renewPrincipal, renewAll }

/// What a bank's message or advice says about a deposit. Rides on a
/// [LoanStatus] whose `outstandingMinor` is the deposit's balance (an FD's
/// principal, an RD's or PPF's running balance) and `principalMinor` the
/// amount booked.
class DepositInfo {
  /// Creates deposit info.
  const DepositInfo(
    this.kind, {
    this.maturity,
    this.maturityAmountMinor,
    this.rateBps,
    this.action,
    this.closed = false,
  });

  /// FD, RD or PPF.
  final DepositKind kind;

  /// Maturity date.
  final CivilDate? maturity;

  /// Maturity amount in paise.
  final int? maturityAmountMinor;

  /// Interest rate in basis points (7.10% = 710).
  final int? rateBps;

  /// Renew or pay out on maturity; null when the message does not say.
  final DepositAction? action;

  /// Matured and paid out, or closed early: the deposit no longer exists.
  final bool closed;

  @override
  bool operator ==(Object other) =>
      other is DepositInfo &&
      other.kind == kind &&
      other.maturity == maturity &&
      other.maturityAmountMinor == maturityAmountMinor &&
      other.rateBps == rateBps &&
      other.action == action &&
      other.closed == closed;

  @override
  int get hashCode => Object.hash(
        kind,
        maturity,
        maturityAmountMinor,
        rateBps,
        action,
        closed,
      );
}

/// What a lender's message says about a loan when it is not a payment: a
/// disbursal, the outstanding principal, or an EMI reminder. Amounts in paise;
/// [last4] is the end of the loan number.
///
/// With [deposit] set it is a bank's FD, RD or PPF account instead:
/// [lender] is the bank, [outstandingMinor] the deposit's balance and
/// [principalMinor] the amount booked.
class LoanStatus {
  /// Creates a status.
  const LoanStatus(
    this.lender,
    this.last4,
    this.principalMinor,
    this.outstandingMinor,
    this.at, {
    this.deposit,
  });

  /// Lender or bank name.
  final String lender;

  /// End of the loan or deposit number.
  final String last4;

  /// Principal, paise.
  final int? principalMinor;

  /// Outstanding amount, paise.
  final int? outstandingMinor;

  /// When the message was sent, epoch ms.
  final int at;

  /// Set for an FD, RD or PPF.
  final DepositInfo? deposit;

  @override
  bool operator ==(Object other) =>
      other is LoanStatus &&
      other.lender == lender &&
      other.last4 == last4 &&
      other.principalMinor == principalMinor &&
      other.outstandingMinor == outstandingMinor &&
      other.at == at &&
      other.deposit == deposit;

  @override
  int get hashCode =>
      Object.hash(lender, last4, principalMinor, outstandingMinor, at, deposit);

  @override
  String toString() =>
      'LoanStatus($lender $last4 $principalMinor $outstandingMinor)';
}
