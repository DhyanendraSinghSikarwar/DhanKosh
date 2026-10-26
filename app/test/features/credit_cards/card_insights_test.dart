// Cycle spend, statement history, paid verification and late flag
// (FR-14-18..22). Fictional figures.
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_insights.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:parser_core/parser_core.dart' show TransactionType;

int day(int m, int d) => CardDay.fromYmd(2026, m, d);
int ms(int m, int d) => CardDay.startMs(day(m, d)) + 43200000;

CardRow bill({
  required int stmt,
  required int due,
  int total = 1000000,
  int min = 50000,
}) =>
    CardRow(
      source: CardDueSource.statement,
      receivedAt: CardDay.startMs(stmt),
      processedAt: CardDay.startMs(stmt),
      totalDueMinor: total,
      minDueMinor: min,
      dueEpochDay: due,
      statementEpochDay: stmt,
    );

void main() {
  final today = day(10, 26);

  test('cycle spend counts debits after the statement day (FR-14-18)', () {
    final flow = [
      CardFlow(ms(10, 5), TransactionType.debit, 90000), // before cycle
      CardFlow(ms(10, 8), TransactionType.debit, 120000),
      CardFlow(ms(10, 9), TransactionType.credit, 30000), // refund ignored
      CardFlow(ms(10, 20), TransactionType.debit, 55000),
      CardFlow(ms(10, 21), TransactionType.transfer, 500000),
    ];
    expect(CardInsightRules.cycleSpend(flow, day(10, 7), today), 175000);
    expect(CardInsightRules.cycleSpend(flow, null, today), isNull);
    expect(CardInsightRules.cycleSpend(const [], day(10, 7), today), 0);
  });

  List<StatementEntry> history({
    List<CardRow>? rows,
    List<CardFlow> flow = const [],
    List<BankDebit> debits = const [],
    Set<int> marked = const {},
    int? todayDay,
  }) =>
      CardInsightRules.history(
        rows: rows ?? [bill(stmt: day(9, 7), due: day(9, 26))],
        flow: flow,
        debits: debits,
        markedPaid: marked,
        today: todayDay ?? today,
      );

  test('overdue with no payment and no bank debit is a late risk (FR-14-22)',
      () {
    final h = history();
    expect(h.single.payment, StatementPayment.unpaid);
    expect(h.single.lateRisk, isTrue);
    expect(
      CardInsights.empty.lateRisk,
      isFalse,
    );
    expect(CardInsights(history: h).lateRisk, isTrue);
  });

  test('not late before the due date', () {
    final h = history(todayDay: day(9, 20));
    expect(h.single.lateRisk, isFalse);
  });

  test('a matching bank debit verifies paid (FR-14-21)', () {
    final h = history(debits: [BankDebit(ms(9, 25), 1000000, 7)]);
    expect(h.single.payment, StatementPayment.paid);
    expect(h.single.verified, isTrue);
    expect(h.single.lateRisk, isFalse);
  });

  test('debit equal to min due is min paid; wrong amount or date ignored', () {
    expect(
      history(debits: [BankDebit(ms(9, 25), 50000, 7)]).single.payment,
      StatementPayment.minPaid,
    );
    expect(
      history(debits: [BankDebit(ms(9, 25), 777700, 7)]).single.payment,
      StatementPayment.unpaid,
    );
    expect(
      history(debits: [BankDebit(ms(8, 1), 1000000, 7)]).single.payment,
      StatementPayment.unpaid,
    );
    // Three days of grace after the due date.
    expect(
      history(debits: [BankDebit(ms(9, 29), 1000000, 7)]).single.payment,
      StatementPayment.paid,
    );
    expect(
      history(debits: [BankDebit(ms(10, 2), 1000000, 7)]).single.payment,
      StatementPayment.unpaid,
    );
  });

  test('card-side transfer pair and payment notices count as paid', () {
    final viaTransfer =
        history(flow: [CardFlow(ms(9, 24), TransactionType.transfer, 1000000)]);
    expect(viaTransfer.single.payment, StatementPayment.paid);
    expect(viaTransfer.single.verified, isTrue);
    final notice = CardRow(
      source: CardDueSource.sms,
      isPayment: true,
      receivedAt: ms(9, 25),
      processedAt: ms(9, 25),
      paymentMinor: 1000000,
      statementEpochDay: day(9, 25),
    );
    final viaNotice = history(
      rows: [bill(stmt: day(9, 7), due: day(9, 26)), notice],
    );
    expect(viaNotice.single.payment, StatementPayment.paid);
    final partial =
        history(flow: [CardFlow(ms(9, 24), TransactionType.transfer, 60000)]);
    expect(partial.single.payment, StatementPayment.minPaid);
  });

  test('Mark paid counts but is not verified', () {
    final h = history(marked: {day(9, 26)});
    expect(h.single.payment, StatementPayment.paid);
    expect(h.single.markedPaid, isTrue);
    expect(h.single.verified, isFalse);
    expect(h.single.lateRisk, isFalse);
  });

  test('history is newest first, one entry per statement day', () {
    final h = history(
      rows: [
        bill(stmt: day(8, 7), due: day(8, 26), total: 700000),
        bill(stmt: day(9, 7), due: day(9, 26)),
        bill(stmt: day(9, 7), due: day(9, 26)),
      ],
    );
    expect(h.map((e) => e.statementDay), [day(9, 7), day(8, 7)]);
    expect(h.last.totalDueMinor, 700000);
  });
}
