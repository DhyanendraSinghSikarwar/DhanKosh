import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/activity_log/domain/activity_stats.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/activity_log/domain/inbox_logic.dart';

void main() {
  final at = DateTime(2026, 10, 31, 9);

  test('alert entries: codes and counts only, grouped under Alerts (FR-22-18)',
      () {
    final sent = ActivityEntry.alert(at: at, kind: 'newTransaction', count: 3);
    final logged =
        ActivityEntry.alert(at: at, kind: 'budgetWarning', notified: false);
    expect(sent.source, ActivitySource.alerts);
    expect(sent.note, 'sent:newTransaction');
    expect(logged.note, 'log:budgetWarning');
    expect(InboxLogic.groupOf(sent), InboxGroup.alerts);
    expect(ActivityStats.title(sent), 'Alerts');
    expect(ActivityStats.subtitle(sent), 'New transaction ×3 · notified');
    expect(
      ActivityStats.subtitle(logged),
      'Budget warning · no notification',
    );
    expect(ActivityStats.totals([sent, logged]).added, 0);
    expect(ActivitySource.fromCode('ALERTS'), ActivitySource.alerts);
  });
}
