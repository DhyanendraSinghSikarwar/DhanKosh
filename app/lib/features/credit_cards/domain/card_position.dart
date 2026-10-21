import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:parser_core/parser_core.dart';

/// Tuning constants of the card position (memory 14 section 10).
abstract final class CardDueRules {
  /// A bill whose due date is older than this is stale.
  static const staleDays = 35;

  /// Flow window length.
  static const windowDays = 60;

  /// Typical statement to due gap.
  static const dueGapDays = 19;
}

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
int _floor0(int v) => v < 0 ? 0 : v;

// Net card spend in [fromMs, toMs): DEBIT adds, CREDIT subtracts, floored.
int _net(List<CardFlow> flow, int fromMs, [int? toMs]) => _floor0(
      _sum(
        flow
            .where(
              (f) => f.timestampMs >= fromMs && (toMs == null || f.timestampMs < toMs),
            )
            .map(
              (f) => switch (f.type) {
                TransactionType.debit => f.inrMinor,
                TransactionType.credit => -f.inrMinor,
                _ => 0,
              },
            ),
      ),
    );

int _transfers(List<CardFlow> flow, int fromMs) => _sum(
      flow
          .where(
            (f) => f.type == TransactionType.transfer && f.timestampMs >= fromMs,
          )
          .map((f) => f.inrMinor),
    );

int _stmtDay(CardRow r) =>
    r.statementEpochDay ??
    (r.dueEpochDay != null
        ? r.dueEpochDay! - CardDueRules.dueGapDays
        : CardDay.ofMs(r.arrivalMs));

int _cmp(CardRow a, CardRow b) {
  final c = _stmtDay(a).compareTo(_stmtDay(b));
  if (c != 0) return c;
  final d = a.arrivalMs.compareTo(b.arrivalMs);
  return d != 0 ? d : a.processedAt.compareTo(b.processedAt);
}

CardRow? _newest(Iterable<CardRow> rows) =>
    rows.isEmpty ? null : rows.reduce((a, b) => _cmp(a, b) >= 0 ? a : b);

/// The card position without any override (`CardDues.basePosition`,
/// FR-14-02..05). [rows] are the usable records of this card (locked and
/// unreadable statements already left out); [available] is the current
/// available limit; [flow] the card movements; [today] an epoch day.
/// [trust] forces a present bill to count even if an expected statement is
/// missing (a bill that arrived after a manual edit).
CardPosition basePosition({
  required List<CardRow> rows,
  required int? available,
  required List<CardFlow> flow,
  required int today,
  bool trust = false,
}) {
  final payments = rows.where((r) => r.isPayment).toList();
  final bills = rows.where((r) => !r.isPayment).toList();

  int paidSince(int? day) {
    final start = day == null ? 0 : CardDay.startMs(day);
    final fromFlow = _transfers(flow, start);
    final fromRows = _sum(
      payments
          .where(
            (p) => day == null || (p.statementEpochDay ?? CardDay.ofMs(p.arrivalMs)) >= day,
          )
          .map((p) => p.paymentMinor ?? 0),
    );
    return fromFlow > fromRows ? fromFlow : fromRows;
  }

  final bill = _newest(bills.where((r) => r.totalDueMinor != null));
  final limit = _newest(bills.where((r) => r.creditLimitMinor != null))
      ?.creditLimitMinor;
  final dueDay = bill?.dueEpochDay;
  final billStmt = bill == null ? null : _stmtDay(bill);
  final gap = (dueDay != null && billStmt != null)
      ? (dueDay - billStmt).clamp(10, 30)
      : CardDueRules.dueGapDays;
  final stale = dueDay != null && dueDay < today - CardDueRules.staleDays;

  final ref = _newest(
    bills.where((r) => r.statementEpochDay != null || r.dueEpochDay != null),
  );
  final refStmt = ref == null
      ? null
      : (ref.statementEpochDay ??
          (ref.dueEpochDay != null ? ref.dueEpochDay! - gap : null));
  final expected =
      refStmt == null ? null : CardDay.latestWithDom(CardDay.dayOfMonth(refStmt), today);

  final covered = bill != null &&
      !stale &&
      (trust || expected == null || billStmt == null || billStmt >= expected);

  if (covered) {
    final billed = _floor0(bill.totalDueMinor! - paidSince(billStmt));
    return CardPosition(
      billedMinor: billed,
      minDueMinor: billed > 0 ? bill.minDueMinor : null,
      dueDay: dueDay,
      statementDay: billStmt,
      limitMinor: limit,
      unbilledMinor: _net(flow, CardDay.startMs(billStmt! + 1)),
      source: bill.source,
      sourceAtMs: bill.arrivalMs,
    );
  }

  if (expected != null && refStmt != null) {
    final prev = CardDay.sameDomPrevMonth(expected);
    final carried = bill != null && !stale && billStmt != null && billStmt >= prev - 3;
    final base = carried ? billStmt : prev;
    final gross = (carried ? bill.totalDueMinor! : 0) +
        _net(flow, CardDay.startMs(base + 1), CardDay.startMs(expected + 1)) -
        paidSince(base);
    if (gross > 0 || carried) {
      return CardPosition(
        billedMinor: _floor0(gross),
        dueDay: expected + gap,
        statementDay: expected,
        limitMinor: limit,
        unbilledMinor: _net(flow, CardDay.startMs(expected + 1)),
        estimated: true,
        source: carried ? bill.source : null,
        sourceAtMs: carried ? bill.arrivalMs : null,
      );
    }
  }

  int? outstanding;
  if (limit != null && available != null && limit >= available) {
    outstanding = limit - available;
  } else if (flow.any((f) => f.type == TransactionType.debit)) {
    final lastTransfer = flow
        .where((f) => f.type == TransactionType.transfer)
        .map((f) => f.timestampMs)
        .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    outstanding = _net(flow, lastTransfer ?? 0);
  }
  return CardPosition(limitMinor: limit, outstandingMinor: outstanding);
}

/// The position shown to the user: [basePosition] with the manual [override]
/// applied unless a newer bill or payments make it stale (FR-14-07, FR-14-08).
CardPosition cardPosition({
  required List<CardRow> rows,
  required CardOverride? override,
  required int? available,
  required List<CardFlow> flow,
  required int today,
}) {
  final o = (override == null || override.isEmpty) ? null : override;
  if (o == null) {
    return basePosition(rows: rows, available: available, flow: flow, today: today);
  }
  final arrivedAfter =
      rows.any((r) => r.carriesBill && r.arrivalMs > o.setAt);
  if (arrivedAfter) {
    return basePosition(
      rows: rows,
      available: available,
      flow: flow,
      today: today,
      trust: true,
    );
  }
  final base = basePosition(rows: rows, available: available, flow: flow, today: today);
  final setDay = CardDay.ofMs(o.setAt);
  final fromRows = _sum(
    rows
        .where(
          (r) => r.isPayment && (r.statementEpochDay ?? CardDay.ofMs(r.arrivalMs)) >= setDay,
        )
        .map((r) => r.paymentMinor ?? 0),
  );
  final fromFlow = _transfers(flow, o.setAt);
  final paid = fromFlow > fromRows ? fromFlow : fromRows;
  final spent = _net(flow, o.setAt);
  final billed = o.billedMinor == null ? null : o.billedMinor! - paid;
  final outstanding =
      o.outstandingMinor == null ? null : o.outstandingMinor! - paid + spent;
  if ((billed != null && billed <= 0) ||
      (outstanding != null && outstanding <= 0)) {
    return base;
  }
  return CardPosition(
    billedMinor: billed ?? base.billedMinor,
    minDueMinor:
        o.billedMinor != null ? o.minDueMinor : (o.minDueMinor ?? base.minDueMinor),
    dueDay: o.dueEpochDay ?? base.dueDay,
    statementDay: base.statementDay,
    limitMinor: base.limitMinor,
    unbilledMinor:
        o.unbilledMinor == null ? base.unbilledMinor : o.unbilledMinor! + spent,
    outstandingMinor: outstanding ?? base.outstandingMinor,
    estimated: false,
    billedEdited: o.billedMinor != null,
    minDueEdited: o.minDueMinor != null,
    dueEdited: o.dueEpochDay != null,
    unbilledEdited: o.unbilledMinor != null,
    outstandingEdited: o.outstandingMinor != null,
    calculated: base,
    source: CardDueSource.manual,
    sourceAtMs: o.setAt,
  );
}
