import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/activity_log/domain/inbox_logic.dart';
import 'package:hisaab/features/dashboard_home/domain/home_attention.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';

// Home composition (F-17): reads other features through their providers so
// Home presentation never imports another feature (ADR-0010).

/// Epoch ms the Inbox was last opened (FR-22-16).
final activityLastSeenProvider = StreamProvider<int>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watch(SettingKeys.activityLastSeen),
);

/// Unread Inbox entries for the bell badge; 0 until both sources load
/// (FR-22-16).
final inboxUnreadProvider = Provider<int>((ref) {
  final entries = ref.watch(activityEntriesProvider).value;
  final seen = ref.watch(activityLastSeenProvider).value;
  if (entries == null || seen == null) return 0;
  return InboxLogic.unread(entries, seen);
});

/// Net worth for the Home card (FR-17-26): null while loading.
final homeNetWorthProvider = Provider<
    ({
      int netMinor,
      bool empty,
      NetWorthChange? change,
    })?>((ref) {
  final nw = ref.watch(netWorthProvider).value;
  if (nw == null) return null;
  final points = ref.watch(netWorthPointsProvider).value ?? const [];
  final today = Ist.dayOf(DateTime.now().millisecondsSinceEpoch);
  return (
    netMinor: nw.netMinor,
    empty: nw.parts.isEmpty && nw.assetsMinor == 0 && nw.liabilitiesMinor == 0,
    change: NetWorthChange.of(
      nw.netMinor,
      [for (final p in points) (day: p.day, netMinor: p.netMinor)],
      today,
    ),
  );
});

/// Rows of the Needs attention block (FR-17-25).
final homeAttentionProvider = Provider<List<AttentionItem>>((ref) {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final today = Ist.dateOf(nowMs);
  final todayDay = Ist.dayOf(nowMs);
  final bills = ref.watch(billsProvider).value ?? const [];
  final cards = ref.watch(cardLimitsProvider).value ?? const [];
  final statements = ref.watch(statementsProvider).value ?? const [];
  return buildAttention(
    reviewCount: ref.watch(homeReviewCountProvider).value ?? 0,
    bills: [
      for (final b in bills)
        if (!b.income) (name: b.name, days: b.nextDue.difference(today).inDays),
    ],
    lockedStatements:
        statements.where((s) => s.status == StatementStatus.locked).length,
    unreadableStatements:
        statements.where((s) => s.status == StatementStatus.unreadable).length,
    cards: [
      for (final c in cards)
        if (!c.paid && c.owedMinor > 0 && c.dueDay != null)
          (name: c.name, days: c.dueDay! - todayDay),
    ],
  );
});
