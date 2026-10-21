import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_matcher.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/domain/card_notice_keys.dart';
import 'package:hisaab/features/credit_cards/domain/card_position.dart';
import 'package:hisaab/features/credit_cards/domain/card_reminder_plan.dart';
import 'package:parser_core/parser_core.dart' show TransactionType;

int ms(int y, int m, int d) =>
    DateTime.utc(y, m, d, 6, 30).millisecondsSinceEpoch; // noon IST
int day(int y, int m, int d) => CardDay.fromYmd(y, m, d);

CardRow bill({
  required int total,
  required int stmt,
  required int due,
  required int arrival,
  int? min,
  int? limit,
}) =>
    CardRow(
      source: CardDueSource.sms,
      receivedAt: arrival,
      processedAt: arrival,
      totalDueMinor: total,
      minDueMinor: min,
      dueEpochDay: due,
      statementEpochDay: stmt,
      creditLimitMinor: limit,
    );

void main() {
  final today = day(2026, 10, 12);

  // FR-14-02, FR-14-03, FR-14-04 (memory 14 worked example 1).
  test('covered bill: billed reduced by payment, unbilled from flow', () {
    final p = cardPosition(
      rows: [
        bill(
          total: 1234500,
          min: 62000,
          stmt: day(2026, 10, 5),
          due: day(2026, 10, 24),
          arrival: ms(2026, 10, 6),
          limit: 10000000,
        ),
      ],
      override: null,
      available: 7000000,
      flow: [
        CardFlow(ms(2026, 10, 8), TransactionType.debit, 300000),
        CardFlow(ms(2026, 10, 12), TransactionType.transfer, 500000),
      ],
      today: today,
    );
    expect(p.billedMinor, 734500);
    expect(p.minDueMinor, 62000);
    expect(p.unbilledMinor, 300000);
    expect(p.estimated, isFalse);
    expect(p.dueDay, day(2026, 10, 24));
    expect(p.limitLeft(p.limitMinor, 7000000), 7000000);
    expect(p.owedMinor, 734500);
  });

  test('fully paid bill drops min due, floors at zero', () {
    final p = basePosition(
      rows: [
        bill(
          total: 100000,
          min: 5000,
          stmt: day(2026, 10, 5),
          due: day(2026, 10, 24),
          arrival: ms(2026, 10, 6),
        ),
        CardRow(
          source: CardDueSource.sms,
          isPayment: true,
          receivedAt: ms(2026, 10, 9),
          processedAt: ms(2026, 10, 9),
          paymentMinor: 150000,
          statementEpochDay: day(2026, 10, 9),
        ),
      ],
      available: null,
      flow: const [],
      today: today,
    );
    expect(p.billedMinor, 0);
    expect(p.minDueMinor, isNull);
    expect(p.owedMinor, 0);
  });

  // FR-14-05 (worked example 2).
  test('estimated bill from the usual statement day', () {
    final p = basePosition(
      rows: [
        bill(
          total: 1000000,
          stmt: day(2026, 9, 5),
          due: day(2026, 9, 24),
          arrival: ms(2026, 9, 6),
        ),
      ],
      available: null,
      flow: [
        CardFlow(ms(2026, 9, 10), TransactionType.debit, 400000),
        CardFlow(ms(2026, 9, 20), TransactionType.transfer, 1000000),
      ],
      today: today,
    );
    expect(p.estimated, isTrue);
    expect(p.billedMinor, 400000);
    expect(p.minDueMinor, isNull);
    expect(p.statementDay, day(2026, 10, 5));
    expect(p.dueDay, day(2026, 10, 24));
  });

  test('outstanding only from limit minus available', () {
    final p = basePosition(
      rows: [
        const CardRow(
          source: CardDueSource.statement,
          receivedAt: 1,
          processedAt: 1,
          creditLimitMinor: 10000000,
        ),
      ],
      available: 9000000,
      flow: const [],
      today: today,
    );
    expect(p.billedMinor, isNull);
    expect(p.outstandingMinor, 1000000);
    expect(p.owedMinor, 1000000);
  });

  // FR-14-07, FR-14-08 (worked examples 3 and 4).
  test('override applies, then is dropped when payments cover it', () {
    final rows = <CardRow>[];
    final o = CardOverride(
      cardKey: 'hdfc:1234',
      setAt: ms(2026, 10, 10),
      billedMinor: 800000,
      unbilledMinor: 100000,
    );
    final applied = cardPosition(
      rows: rows,
      override: o,
      available: null,
      flow: [CardFlow(ms(2026, 10, 11), TransactionType.debit, 20000)],
      today: today,
    );
    expect(applied.billedMinor, 800000);
    expect(applied.unbilledMinor, 120000);
    expect(applied.billedEdited, isTrue);
    expect(applied.source, CardDueSource.manual);
    expect(applied.calculated, isNotNull);

    final dropped = cardPosition(
      rows: rows,
      override: o,
      available: null,
      flow: [CardFlow(ms(2026, 10, 11), TransactionType.transfer, 800000)],
      today: today,
    );
    expect(dropped.edited, isFalse);
  });

  test('a newer real bill replaces the override', () {
    final p = cardPosition(
      rows: [
        bill(
          total: 500000,
          stmt: day(2026, 10, 11),
          due: day(2026, 10, 30),
          arrival: ms(2026, 10, 11),
        ),
      ],
      override: CardOverride(
        cardKey: 'hdfc:1234',
        setAt: ms(2026, 10, 10),
        billedMinor: 800000,
      ),
      available: null,
      flow: const [],
      today: today,
    );
    expect(p.billedMinor, 500000);
    expect(p.edited, isFalse);
  });

  test('limit left with an edited figure', () {
    const p = CardPosition(
      billedMinor: 2000000,
      unbilledMinor: 500000,
      billedEdited: true,
    );
    expect(p.limitLeft(10000000, 1), 7500000);
    expect(p.limitLeft(1000000, 1), 0);
  });

  // FR-14-10 (worked example 5).
  test('reminder stages', () {
    final due = day(2026, 10, 24);
    DueStage? at(int d, {Set<DueStage> sent = const {}}) =>
        CardReminderPlan.next(today: day(2026, 10, d), due: due, sent: sent);
    expect(at(19), DueStage.days5);
    expect(at(19, sent: {DueStage.days5}), isNull);
    expect(at(22), DueStage.days2);
    expect(at(24), DueStage.dueDay);
    expect(at(25), DueStage.overdue);
    expect(
      CardReminderPlan.next(
        today: day(2026, 11, 1),
        due: due,
        sent: const {},
      ),
      isNull,
    );
    expect(
      CardReminderPlan.next(
        today: day(2026, 10, 19),
        due: due,
        sent: const {},
        paid: true,
      ),
      isNull,
    );
    expect(
      CardReminderPlan.markSent(DueStage.days2),
      {DueStage.days5, DueStage.days2},
    );
  });

  // FR-14-06.
  test('card matching and notice keys', () {
    expect(CardMatcher.bankMatches('Axis Bank', 'Axis'), isTrue);
    expect(CardMatcher.bankMatches('HDFC Bank', 'ICICI Bank'), isFalse);
    const hdfc = CardRef(id: 1, bankName: 'HDFC Bank', last4: '5678');
    const icici = CardRef(id: 2, bankName: 'ICICI Bank', last4: '1111');
    final rows = [
      const CardRow(
        source: CardDueSource.sms,
        receivedAt: 1,
        processedAt: 1,
        bankName: 'HDFC',
        last4: '5678',
        totalDueMinor: 1,
      ),
      const CardRow(
        source: CardDueSource.sms,
        receivedAt: 2,
        processedAt: 2,
        bankName: 'HDFC',
        totalDueMinor: 2,
      ),
      const CardRow(
        source: CardDueSource.sms,
        receivedAt: 3,
        processedAt: 3,
        bankName: 'ICICI',
        last4: '1111',
        totalDueMinor: 3,
      ),
    ];
    expect(
      CardMatcher.rowsFor(hdfc, [hdfc, icici], rows)
          .map((r) => r.totalDueMinor),
      [1, 2],
    );
    expect(
      CardNoticeKeys.due(bank: 'HDFC Bank', last4: '5678', day: 5),
      'carddue:hdfc:5678:5',
    );
    expect(
      CardNoticeKeys.payment(bank: 'Axis', last4: '1', day: 5, amountMinor: 9),
      'cardpay:axis:1:5:9',
    );
  });
}
