import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/activity_log/domain/inbox_logic.dart';

ActivityEntry _e(
  ActivitySource s,
  int ms, {
  String? error,
  int statements = 0,
}) =>
    ActivityEntry(
      at: DateTime.fromMillisecondsSinceEpoch(ms),
      source: s,
      error: error,
      statements: statements,
    );

void main() {
  // FR-22-16
  test('unread counts entries strictly newer than last seen', () {
    final l = [
      _e(ActivitySource.smsScan, 300),
      _e(ActivitySource.gmail, 200),
      _e(ActivitySource.smsLive, 100),
    ];
    expect(InboxLogic.unread(l, 0), 3);
    expect(InboxLogic.unread(l, 100), 2);
    expect(InboxLogic.unread(l, 300), 0);
    expect(InboxLogic.isUnread(l.first, 299), isTrue);
    expect(InboxLogic.isUnread(l.first, 300), isFalse);
  });

  // FR-22-17
  test('groups by type', () {
    expect(
      InboxLogic.groupOf(_e(ActivitySource.smsScan, 1)),
      InboxGroup.scans,
    );
    expect(
      InboxLogic.groupOf(_e(ActivitySource.smsLive, 1)),
      InboxGroup.scans,
    );
    expect(
      InboxLogic.groupOf(_e(ActivitySource.gmail, 1)),
      InboxGroup.imports,
    );
    expect(
      InboxLogic.groupOf(_e(ActivitySource.statements, 1)),
      InboxGroup.imports,
    );
    expect(
      InboxLogic.groupOf(_e(ActivitySource.notifications, 1)),
      InboxGroup.alerts,
    );
    expect(
      InboxLogic.groupOf(_e(ActivitySource.problems, 1)),
      InboxGroup.problems,
    );
    expect(
      InboxLogic.groupOf(_e(ActivitySource.smsScan, 1, error: 'permission')),
      InboxGroup.problems,
    );
  });

  // FR-22-15
  test('sender codes keep bank headers and drop anything number-like', () {
    expect(InboxLogic.senderCode('AX-HDFCBK'), 'AX-HDFCBK');
    expect(InboxLogic.senderCode('hdfcbk'), 'HDFCBK');
    expect(InboxLogic.senderCode('+919876543210'), 'OTHER');
    expect(InboxLogic.senderCode('9876543210'), 'OTHER');
    expect(InboxLogic.senderCode('Rs 500 debited'), 'OTHER');
    expect(InboxLogic.senderCode('a@upi'), 'OTHER');
    expect(
      InboxLogic.topSenderCode(['AX-HDFCBK', 'VM-SBIINB', 'AX-HDFCBK']),
      'AX-HDFCBK',
    );
    expect(InboxLogic.topSenderCode(const []), isNull);
  });
}
