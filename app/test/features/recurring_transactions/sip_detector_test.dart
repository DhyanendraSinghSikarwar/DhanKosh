// SIP detection and schedules (FR-12-17..20).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip_detector.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

SipEvent ev(String name, int y, int m, int d, int rupees) => SipEvent(
      name: name,
      atMs: DateTime.utc(y, m, d, 6).millisecondsSinceEpoch,
      amountMinor: rupees * 100,
    );

void main() {
  final today = DateTime.utc(2026, 10, 26);

  test('monthly SIP: next date, total invested, instalments (FR-12-17)', () {
    final out = SipDetector.detect(
      [
        ev('Nifty Index Fund', 2026, 8, 5, 5000),
        ev('Nifty Index Fund', 2026, 9, 5, 5000),
        ev('Nifty Index Fund', 2026, 10, 5, 5000),
      ],
      today,
    );
    expect(out, hasLength(1));
    expect(out.single.frequency, SipFrequency.monthly);
    expect(out.single.nextDate, DateTime.utc(2026, 11, 5));
    expect(out.single.totalInvestedMinor, 1500000);
    expect(out.single.instalments, 3);
    expect(out.single.detected, isTrue);
  });

  test('weekly needs three instalments; quarterly two (FR-12-17)', () {
    final weekly = SipDetector.detect(
      [
        ev('Gold Fund', 2026, 10, 5, 500),
        ev('Gold Fund', 2026, 10, 12, 500),
        ev('Gold Fund', 2026, 10, 19, 500),
      ],
      today,
    );
    expect(weekly.single.frequency, SipFrequency.weekly);
    expect(weekly.single.nextDate, DateTime.utc(2026, 10, 26));
    expect(
      SipDetector.detect(
        [
          ev('Gold Fund', 2026, 10, 12, 500),
          ev('Gold Fund', 2026, 10, 19, 500),
        ],
        today,
      ),
      isEmpty,
    );
    final q = SipDetector.detect(
      [ev('Debt Fund', 2026, 4, 10, 9000), ev('Debt Fund', 2026, 7, 10, 9000)],
      DateTime.utc(2026, 8),
    );
    expect(q.single.frequency, SipFrequency.quarterly);
    expect(q.single.nextDate, DateTime.utc(2026, 10, 10));
  });

  test('stale, uneven or one-off series are not SIPs', () {
    expect(
      SipDetector.detect(
        [ev('Old Fund', 2026, 3, 5, 5000), ev('Old Fund', 2026, 4, 5, 5000)],
        today,
      ),
      isEmpty,
    );
    expect(
      SipDetector.detect(
        [
          ev('Mixed Fund', 2026, 9, 5, 5000),
          ev('Mixed Fund', 2026, 10, 5, 90000),
        ],
        today,
      ),
      isEmpty,
    );
    expect(
      SipDetector.detect([ev('One Fund', 2026, 10, 5, 5000)], today),
      isEmpty,
    );
  });

  test('a ledger row and the MF order of one purchase count once', () {
    final out = SipDetector.detect(
      [
        ev('Nifty Index Fund', 2026, 9, 5, 5000),
        ev('NIFTY INDEX FUND', 2026, 9, 5, 5000),
        ev('Nifty Index Fund', 2026, 10, 5, 5000),
      ],
      today,
    );
    expect(out.single.instalments, 2);
    expect(out.single.totalInvestedMinor, 1000000);
  });

  test('events come from INVESTMENT rows only (FR-12-18)', () {
    final events = SipDetector.eventsFromLedger([
      fakeTx(
        1,
        500000,
        DateTime.utc(2026, 10, 5, 6),
        merchant: 'Zerodha Coin',
        type: TransactionType.investment,
      ),
      fakeTx(2, 500000, DateTime.utc(2026, 10, 5, 6), merchant: 'Swiggy'),
      fakeTx(
        3,
        500000,
        DateTime.utc(2026, 10, 5, 6),
        type: TransactionType.investment,
        needsReview: true,
        merchant: 'Hold',
      ),
    ]);
    expect(events.map((e) => e.name), ['Zerodha Coin']);
  });

  group('user SIPs (FR-12-19)', () {
    SipItem item(SipFrequency f, {int? dom, int? wd, int start = 20000}) =>
        SipItem(
          id: 1,
          name: 'Nifty Index Fund',
          amountMinor: 100000,
          frequency: f,
          dayOfMonth: dom,
          weekday: wd,
          startDay: start,
          createdAt: 1,
        );
    final startDay =
        DateTime.utc(2026, 9).difference(DateTime.utc(1970)).inDays;

    test('next date: weekly, monthly clamped, daily', () {
      // 2026-10-26 is a Monday.
      expect(
        SipDetector.nextDateOf(item(SipFrequency.weekly, wd: 3), today),
        DateTime.utc(2026, 10, 28),
      );
      expect(
        SipDetector.nextDateOf(item(SipFrequency.weekly, wd: 1), today),
        today,
      );
      expect(
        SipDetector.nextDateOf(
          item(SipFrequency.monthly, dom: 31),
          DateTime.utc(2027, 2, 10),
        ),
        DateTime.utc(2027, 2, 28),
      );
      expect(
        SipDetector.nextDateOf(item(SipFrequency.monthly, dom: 5), today),
        DateTime.utc(2026, 11, 5),
      );
      expect(SipDetector.nextDateOf(item(SipFrequency.daily), today), today);
    });

    test('instalments due so far', () {
      expect(
        SipDetector.instalmentsUntil(
          item(SipFrequency.monthly, dom: 5, start: startDay),
          today,
        ),
        2, // 5 Oct only? start 1 Sep: 5 Sep and 5 Oct
      );
      expect(
        SipDetector.instalmentsUntil(
          item(SipFrequency.weekly, wd: 1, start: startDay),
          today,
        ),
        8, // Mondays 7 Sep .. 26 Oct
      );
      expect(
        SipDetector.instalmentsUntil(
          item(SipFrequency.daily, start: startDay),
          today,
        ),
        56,
      );
      expect(
        SipDetector.instalmentsUntil(
          item(SipFrequency.daily, start: startDay + 200),
          today,
        ),
        0,
      );
    });

    test('a user SIP replaces the detected one and keeps its records', () {
      final detected = SipDetector.detect(
        [
          ev('Nifty Index Fund', 2026, 9, 5, 5000),
          ev('Nifty Index Fund', 2026, 10, 5, 5000),
        ],
        today,
      );
      final out = SipDetector.withManual(
        detected,
        [item(SipFrequency.monthly, dom: 5, start: startDay)],
        today,
      );
      expect(out, hasLength(1));
      expect(out.single.manualId, 1);
      expect(out.single.totalInvestedMinor, 1000000);
      expect(out.single.amountMinor, 100000);
    });

    test('a user SIP without records totals amount times instalments', () {
      final out = SipDetector.withManual(
        const [],
        [item(SipFrequency.monthly, dom: 5, start: startDay)],
        today,
      );
      expect(out.single.totalInvestedMinor, 200000);
    });
  });

  test('draft validation', () {
    SipDraft d(SipFrequency f, {int? dom, int? wd, int amount = 100}) =>
        SipDraft(
          name: 'X',
          amountMinor: amount,
          frequency: f,
          startDay: 1,
          dayOfMonth: dom,
          weekday: wd,
        );
    expect(d(SipFrequency.monthly, dom: 5).validate(), isNull);
    expect(d(SipFrequency.monthly, dom: 40).validate(), isNotNull);
    expect(d(SipFrequency.weekly).validate(), isNotNull);
    expect(d(SipFrequency.weekly, wd: 2).validate(), isNull);
    expect(d(SipFrequency.daily, amount: 0).validate(), isNotNull);
    expect(d(SipFrequency.quarterly).validate(), isNotNull);
  });
}
