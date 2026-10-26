import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/domain/card_position.dart';
import 'package:parser_core/parser_core.dart' show TransactionType;

/// A debit or transfer row on a non-card account, used only to verify a card
/// bill was paid (FR-14-21).
class BankDebit {
  /// Creates a debit.
  const BankDebit(this.timestampMs, this.inrMinor, this.accountId);

  final int timestampMs;
  final int inrMinor;
  final int? accountId;
}

/// Bank-side movements of the ledger (read only, FR-14-21).
abstract interface class CardBillDebitSource {
  /// Debits and transfers since [fromMs] on accounts other than
  /// [excludeAccountId].
  Future<List<BankDebit>> debitsSince(int fromMs, {int? excludeAccountId});
}

/// Payment state of one statement (FR-14-20).
enum StatementPayment {
  /// Full amount paid.
  paid('Paid'),

  /// At least the minimum due paid.
  minPaid('Min paid'),

  /// Nothing found.
  unpaid('Unpaid');

  const StatementPayment(this.label);

  /// Display name.
  final String label;
}

/// One imported statement or bill notice of a card (FR-14-19).
class StatementEntry {
  /// Creates an entry.
  const StatementEntry({
    required this.source,
    required this.payment,
    this.statementDay,
    this.dueDay,
    this.totalDueMinor,
    this.minDueMinor,
    this.verified = false,
    this.markedPaid = false,
    this.lateRisk = false,
  });

  final CardDueSource source;
  final int? statementDay;
  final int? dueDay;
  final int? totalDueMinor;
  final int? minDueMinor;
  final StatementPayment payment;

  /// A matching bank debit or card-side transfer was found (FR-14-21).
  final bool verified;

  /// The user tapped Mark paid.
  final bool markedPaid;

  /// Due date passed, nothing paid, no matching bank debit (FR-14-22).
  final bool lateRisk;
}

/// Per-card extras for the Cards screen (FR-14-18..22).
class CardInsights {
  /// Creates insights.
  const CardInsights({
    required this.history,
    this.cycleSpendMinor,
    this.cycleStartDay,
  });

  /// No data.
  static const empty = CardInsights(history: []);

  /// Spend since the last statement day; null when no statement day is
  /// known.
  final int? cycleSpendMinor;
  final int? cycleStartDay;

  /// Newest statement first.
  final List<StatementEntry> history;

  /// The newest statement is at risk of being late.
  bool get lateRisk => history.isNotEmpty && history.first.lateRisk;
}

/// Pure card insight maths (memory 14 section 10).
abstract final class CardInsightRules {
  /// Amounts this close (paise) count as equal.
  static const tolerance = 100;

  /// Bank debits count up to this many days after the due date.
  static const graceDays = 3;

  /// Payments count up to this many days after the due date.
  static const payWindowDays = 10;

  /// FR-14-18: spend on the card in the current cycle, from the day after
  /// [statementDay] through [today]. DEBIT rows only, so refunds do not
  /// hide spend. Null without a statement day.
  static int? cycleSpend(List<CardFlow> flow, int? statementDay, int today) {
    if (statementDay == null) return null;
    final from = CardDay.startMs(statementDay + 1);
    final to = CardDay.startMs(today + 1);
    var sum = 0;
    for (final f in flow) {
      if (f.type == TransactionType.debit &&
          f.timestampMs >= from &&
          f.timestampMs < to) {
        sum += f.inrMinor;
      }
    }
    return sum;
  }

  static int _stmtDay(CardRow r) =>
      r.statementEpochDay ??
      (r.dueEpochDay != null
          ? r.dueEpochDay! - CardDueRules.dueGapDays
          : CardDay.ofMs(r.arrivalMs));

  static bool _near(int a, int b) => (a - b).abs() <= tolerance;

  /// FR-14-19..22: statements of one card, newest first. [rows] are the
  /// card's records, [flow] its ledger movements, [debits] bank-side rows,
  /// [markedPaid] the due days the user marked paid, [today] an epoch day.
  static List<StatementEntry> history({
    required List<CardRow> rows,
    required List<CardFlow> flow,
    required List<BankDebit> debits,
    required Set<int> markedPaid,
    required int today,
    int limit = 12,
  }) {
    // One entry per statement day: the row with a total wins, else newest.
    final byDay = <int, CardRow>{};
    for (final r in rows.where((r) => r.carriesBill)) {
      final k = _stmtDay(r);
      final old = byDay[k];
      if (old == null ||
          (old.totalDueMinor == null && r.totalDueMinor != null) ||
          (old.totalDueMinor != null &&
              r.totalDueMinor != null &&
              r.arrivalMs > old.arrivalMs)) {
        byDay[k] = r;
      }
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final payments = rows.where((r) => r.isPayment).toList();
    final out = <StatementEntry>[];
    for (final stmt in days.take(limit)) {
      final r = byDay[stmt]!;
      final due = r.dueEpochDay ?? stmt + CardDueRules.dueGapDays;
      final total = r.totalDueMinor;
      final min = r.minDueMinor;
      final from = CardDay.startMs(stmt + 1);
      final to = CardDay.startMs(due + payWindowDays + 1);
      final transfers = flow
          .where(
            (f) =>
                f.type == TransactionType.transfer &&
                f.timestampMs >= from &&
                f.timestampMs < to,
          )
          .fold<int>(0, (a, f) => a + f.inrMinor);
      final noticed = payments.where((p) {
        final d = p.statementEpochDay ?? CardDay.ofMs(p.arrivalMs);
        return d > stmt && d <= due + payWindowDays;
      }).fold<int>(0, (a, p) => a + (p.paymentMinor ?? 0));
      final evidence = transfers > noticed ? transfers : noticed;
      final debitTo = CardDay.startMs(due + graceDays + 1);
      final matching = [
        for (final d in debits)
          if (d.timestampMs >= from &&
              d.timestampMs < debitTo &&
              total != null &&
              ((_near(d.inrMinor, total)) ||
                  (min != null && min > 0 && _near(d.inrMinor, min))))
            d,
      ];
      final debitFull =
          total != null && matching.any((d) => _near(d.inrMinor, total));
      final marked = markedPaid.contains(due);
      var state = StatementPayment.unpaid;
      if (marked ||
          debitFull ||
          (total != null && evidence >= total - tolerance && evidence > 0)) {
        state = StatementPayment.paid;
      } else if (matching.isNotEmpty ||
          (min != null && min > 0 && evidence >= min - tolerance)) {
        state = StatementPayment.minPaid;
      }
      final verified = matching.isNotEmpty || transfers > 0 || noticed > 0;
      out.add(
        StatementEntry(
          source: r.source,
          statementDay: stmt,
          dueDay: due,
          totalDueMinor: total,
          minDueMinor: min,
          payment: state,
          verified: verified && state != StatementPayment.unpaid,
          markedPaid: marked,
          lateRisk: state == StatementPayment.unpaid &&
              due < today &&
              (total ?? 0) > 0 &&
              matching.isEmpty,
        ),
      );
    }
    return out;
  }

  /// Insights of one card from its [position] and records.
  static CardInsights insights({
    required CardPosition position,
    required List<CardRow> rows,
    required List<CardFlow> flow,
    required List<BankDebit> debits,
    required Set<int> markedPaid,
    required int today,
  }) =>
      CardInsights(
        cycleSpendMinor: cycleSpend(flow, position.statementDay, today),
        cycleStartDay:
            position.statementDay == null ? null : position.statementDay! + 1,
        history: history(
          rows: rows,
          flow: flow,
          debits: debits,
          markedPaid: markedPaid,
          today: today,
        ),
      );
}
