import 'package:hisaab/features/transactions_ledger/domain/day_groups.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Transactions tab segments (FR-08-02..04).
enum LedgerSegment { list, category, calendar, merchant }

/// Caption above the calendar by kind (FR-08-21, memory 08 3.11).
String calendarCaption(TxKind kind) => switch (kind) {
      TxKind.all || TxKind.spends => 'Daily spend',
      TxKind.income => 'Daily income',
      TxKind.transfers => 'Daily transfers',
      TxKind.investments => 'Daily investments',
      TxKind.review => 'Flagged amounts by day',
    };

/// Per local day value in paise for the calendar (FR-08-03): kind ALL sums
/// spends only; other kinds sum the rows listed for that kind.
Map<DateTime, int> dayValues(Iterable<LedgerTx> rows, TxKind kind) {
  final out = <DateTime, int>{};
  for (final t in rows) {
    if (kind == TxKind.all && t.type != TransactionType.debit) continue;
    final v = inrOf(t);
    if (v == null) continue;
    final d = DateTime.fromMillisecondsSinceEpoch(t.timestamp);
    final day = DateTime(d.year, d.month, d.day);
    out[day] = (out[day] ?? 0) + v;
  }
  return out;
}

/// Rows of one merchant (FR-08-04).
class MerchantGroup {
  const MerchantGroup(this.name, this.rows, this.grossMinor);
  final String name;
  final List<LedgerTx> rows;

  /// Sum of INR values, transfers included.
  final int grossMinor;
}

/// Groups by `merchant ?: bankName`, largest gross first (FR-08-04).
List<MerchantGroup> groupByMerchant(Iterable<LedgerTx> rows) {
  final map = <String, List<LedgerTx>>{};
  for (final t in rows) {
    map.putIfAbsent(t.title, () => []).add(t);
  }
  final out = [
    for (final e in map.entries)
      MerchantGroup(
        e.key,
        e.value,
        e.value.fold(0, (s, t) => s + (inrOf(t) ?? 0)),
      ),
  ]..sort((a, b) => b.grossMinor.compareTo(a.grossMinor));
  return out;
}

/// Spends of one category, card and account together (FR-08-23).
class CategoryGroup {
  const CategoryGroup(
    this.category,
    this.rows,
    this.totalMinor,
    this.accountMinor,
    this.cardMinor,
  );
  final Category category;
  final List<LedgerTx> rows;

  /// [accountMinor] plus [cardMinor], refunds already taken off.
  final int totalMinor;

  /// Spend on bank accounts.
  final int accountMinor;

  /// Spend on cards (card refunds reduce it).
  final int cardMinor;
}

/// Groups debits and refunds by category, largest total first. Card and
/// account rows sit together, each tagged in the tile; a refund reduces the
/// category on its own side (FR-08-23, ADR-0011).
List<CategoryGroup> groupByCategory(Iterable<LedgerTx> rows) {
  final map = <Category, List<LedgerTx>>{};
  for (final t in rows) {
    if (t.needsReview) continue;
    final spend =
        t.type == TransactionType.debit && t.category != Category.transfer;
    final refund =
        t.type == TransactionType.credit && t.category == Category.refund;
    if (spend || refund) map.putIfAbsent(t.category, () => []).add(t);
  }
  final out = <CategoryGroup>[];
  for (final e in map.entries) {
    var acc = 0;
    var card = 0;
    for (final t in e.value) {
      final v = (inrOf(t) ?? 0) * (t.type == TransactionType.debit ? 1 : -1);
      if (t.accountKind == AccountKind.card) {
        card += v;
      } else {
        acc += v;
      }
    }
    out.add(CategoryGroup(e.key, e.value, acc + card, acc, card));
  }
  return out..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
}
