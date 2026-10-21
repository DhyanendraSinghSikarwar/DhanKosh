import 'package:hisaab/features/loans/domain/amortization.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

/// A loan account (accounts row with type LOAN) or a merged child of one, as
/// the loan logic needs it (FR-15-01). Money in paise; [startDay] is an epoch
/// day.
class LoanAccount {
  const LoanAccount({
    required this.id,
    required this.bankName,
    this.last4 = '',
    this.nickname,
    this.hidden = false,
    this.principalMinor,
    this.rateBps,
    this.tenureMonths,
    this.startDay,
    this.currentBalanceMinor,
    this.latestBalanceMinor,
    this.balanceUpdatedAt,
    this.mergedIntoId,
  });

  final int id;
  final String bankName;
  final String last4;
  final String? nickname;
  final bool hidden;
  final int? principalMinor;
  final int? rateBps;
  final int? tenureMonths;
  final int? startDay;

  /// Balance used for the parent loan's outstanding (manual else latest).
  final int? currentBalanceMinor;

  /// Latest bank-stated balance (used for merged children).
  final int? latestBalanceMinor;
  final int? balanceUpdatedAt;
  final int? mergedIntoId;
}

/// User links of payments to loans (FR-15-10). Persistence is elsewhere.
class LoanLinks {
  const LoanLinks({
    this.tx = const {},
    this.payee = const {},
    this.manualPayees = const {},
  });

  static const none = LoanLinks();

  /// txId -> loanId.
  final Map<int, int> tx;

  /// payeeKey -> loanId.
  final Map<String, int> payee;
  final Set<String> manualPayees;

  /// `(merchant ?? upiId).trim().lowercase()`; '' when both are null.
  static String keyOf(String? merchant, String? upiId) =>
      (merchant ?? upiId ?? '').trim().toLowerCase();

  /// Old DataStore encodings (backup and import, TC-15-06).
  static String encodeTx(int txId, int loanId) => '$txId:$loanId';
  static String encodePayee(int loanId, String payeeKey) => '$loanId:$payeeKey';

  static LoanLinks decode({
    Iterable<String> tx = const [],
    Iterable<String> payee = const [],
    Iterable<String> manual = const [],
  }) {
    final t = <int, int>{};
    for (final e in tx) {
      final i = e.indexOf(':');
      final a = i < 0 ? null : int.tryParse(e.substring(0, i));
      final b = i < 0 ? null : int.tryParse(e.substring(i + 1));
      if (a != null && b != null) t[a] = b;
    }
    final p = <String, int>{};
    for (final e in payee) {
      final i = e.indexOf(':');
      final loan = i < 0 ? null : int.tryParse(e.substring(0, i));
      if (loan != null) p[e.substring(i + 1)] = loan;
    }
    return LoanLinks(tx: t, payee: p, manualPayees: manual.toSet());
  }

  Set<String> encodeTxSet() =>
      {for (final e in tx.entries) encodeTx(e.key, e.value)};
  Set<String> encodePayeeSet() =>
      {for (final e in payee.entries) encodePayee(e.value, e.key)};
}

enum OutstandingSource { none, bank, schedule }

/// One loan: an account, or an EMI series detected from payments.
class Loan {
  const Loan({
    required this.key,
    required this.accountId,
    required this.name,
    required this.bankName,
    required this.last4,
    required this.emiMinor,
    required this.emiDay,
    required this.paidCount,
    required this.trackedCount,
    required this.totalPaidMinor,
    required this.firstPaid,
    required this.lastPaid,
    required this.nextDue,
    required this.outstandingMinor,
    required this.outstandingSource,
    required this.terms,
    required this.totalEmis,
    required this.remainingEmis,
    required this.payoffDate,
    required this.principalPaidMinor,
    required this.interestPaidMinor,
    required this.totalInterestMinor,
    required this.upcoming,
    required this.payments,
    required this.payingAccountId,
    this.mergedIds = const [],
  });

  /// `acct:<id>` for an account, `payee:<key>` for a detected EMI.
  final String key;
  final int? accountId;
  final String name;
  final String bankName;
  final String? last4;
  final int? emiMinor;
  final int? emiDay;

  /// By the calendar when terms and start day exist, else EMI debits found.
  final int paidCount;
  final int trackedCount;
  final int totalPaidMinor;
  final DateTime? firstPaid;
  final DateTime? lastPaid;
  final DateTime? nextDue;
  final int? outstandingMinor;
  final OutstandingSource outstandingSource;
  final LoanTerms? terms;
  final int? totalEmis;
  final int? remainingEmis;
  final DateTime? payoffDate;
  final int? principalPaidMinor;
  final int? interestPaidMinor;
  final int? totalInterestMinor;

  /// Next instalments (up to 12) when terms are set.
  final List<Instalment> upcoming;

  /// Newest first.
  final List<LedgerTx> payments;
  final int? payingAccountId;
  final List<int> mergedIds;

  bool get detected => accountId == null;
  bool get outstandingFromBank => outstandingSource == OutstandingSource.bank;

  bool get closed =>
      outstandingMinor == 0 || (remainingEmis == 0 && terms != null);

  /// Share repaid 0..1: by principal with terms, else by EMIs; null unknown.
  double? get progress {
    final t = terms;
    final out = outstandingMinor;
    if (t != null && t.principalMinor > 0 && out != null) {
      return (1 - out / t.principalMinor).clamp(0, 1).toDouble();
    }
    final total = totalEmis;
    if (total != null && total > 0)
      return (paidCount / total).clamp(0, 1).toDouble();
    final rem = remainingEmis;
    if (rem != null && paidCount + rem > 0)
      return paidCount / (paidCount + rem);
    return null;
  }
}

/// A likely duplicate pair of loan accounts (FR-15-12).
class LoanDuplicate {
  const LoanDuplicate({required this.from, required this.into});

  final Loan from;
  final Loan into;

  /// `min-max` of the account ids; used for "Not duplicates".
  String get key {
    final x = from.accountId ?? 0;
    final y = into.accountId ?? 0;
    return '${x < y ? x : y}-${x < y ? y : x}';
  }
}
