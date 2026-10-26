import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/dashboard_home/domain/home_attention.dart';

void main() {
  // FR-17-25
  group('buildAttention', () {
    test('empty when nothing needs attention', () {
      expect(
        buildAttention(
          reviewCount: 0,
          bills: const [],
          lockedStatements: 0,
          unreadableStatements: 0,
          cards: const [],
        ),
        isEmpty,
      );
    });

    test('fixed order, 7 day horizon, no amounts', () {
      final items = buildAttention(
        reviewCount: 3,
        bills: const [
          (name: 'Netflix', days: 5),
          (name: 'Rent', days: 2),
          (name: 'Insurance', days: 20),
        ],
        lockedStatements: 1,
        unreadableStatements: 1,
        cards: const [(name: 'HDFC ••4321', days: 0)],
      );
      expect(
        items.map((i) => i.kind),
        [
          AttentionKind.duplicates,
          AttentionKind.bill,
          AttentionKind.statement,
          AttentionKind.card,
        ],
      );
      expect(items[0].title, '3 to review');
      expect(items[0].route, '/review');
      expect(items[1].title, '2 bills due');
      expect(items[1].detail, 'Next: Rent · Due in 2 days');
      expect(items[2].title, '2 statements need attention');
      expect(items[2].route, '/statements');
      expect(items[3].title, 'HDFC ••4321');
      expect(items[3].detail, 'Due today');
      for (final i in items) {
        expect(i.title + i.detail, isNot(contains('₹')));
      }
    });

    test('single bill names the bill; far bills hidden', () {
      final items = buildAttention(
        reviewCount: 0,
        bills: const [(name: 'Gym', days: 1), (name: 'Tax', days: 30)],
        lockedStatements: 0,
        unreadableStatements: 0,
        cards: const [],
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'Gym');
      expect(items.single.detail, 'Due tomorrow');
    });
  });

  // FR-17-26
  group('NetWorthChange', () {
    test('compares with newest point before today', () {
      final c = NetWorthChange.of(
        11000000,
        const [
          (day: 100, netMinor: 8000000),
          (day: 101, netMinor: 10000000),
          (day: 102, netMinor: 10900000),
        ],
        102,
      );
      expect(c!.deltaMinor, 1000000);
      expect(c.percentTenths, 100);
    });

    test('falls back to the only point; null without points', () {
      final c = NetWorthChange.of(
        9000000,
        const [(day: 5, netMinor: 10000000)],
        5,
      );
      expect(c!.deltaMinor, -1000000);
      expect(c.percentTenths, -100);
      expect(NetWorthChange.of(1, const [], 5), isNull);
    });

    test('no percent when previous is not positive', () {
      final c = NetWorthChange.of(
        500,
        const [(day: 1, netMinor: -100)],
        2,
      );
      expect(c!.deltaMinor, 600);
      expect(c.percentTenths, isNull);
    });
  });
}
