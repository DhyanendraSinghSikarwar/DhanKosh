import 'package:hisaab/features/credit_cards/domain/card_insights.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart' show TransactionType;

/// [CardBillDebitSource] reading the ledger through [TransactionRepository]
/// (read only, FR-14-18).
class CardBillDebitSourceImpl implements CardBillDebitSource {
  /// Creates the source.
  const CardBillDebitSourceImpl(this._txs);

  final TransactionRepository _txs;

  @override
  Future<List<BankDebit>> debitsSince(
    int fromMs, {
    int? excludeAccountId,
  }) async {
    final rows = await _txs.watch(LedgerFilter(fromMs: fromMs)).first;
    return [
      for (final t in rows)
        if ((t.type == TransactionType.debit ||
                t.type == TransactionType.transfer) &&
            t.inrMinor != null &&
            t.duplicateOfId == null &&
            t.accountId != excludeAccountId)
          BankDebit(t.timestamp, t.inrMinor!, t.accountId),
    ];
  }
}
