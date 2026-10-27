import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/core/utils/combine_latest.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/activity_log/domain/inbox_logic.dart';
import 'package:hisaab/features/dashboard_home/domain/home_attention.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/news_support_updates/domain/update_keys.dart';
import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart' show Category;

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

/// Newest version the last update check found, `''` when none (FR-31-33).
final knownUpdateProvider = StreamProvider<String>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(knownUpdateKey),
);

/// Version whose Home notice was dismissed (FR-31-33).
final dismissedUpdateProvider = StreamProvider<String>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watch(updateNoticeDismissedKey),
);

/// Version of a newer release the last check found, hidden once dismissed
/// (FR-31-33); null when none.
final homeUpdateVersionProvider = Provider<String?>((ref) {
  final known = ref.watch(knownUpdateProvider).value ?? '';
  final dismissed = ref.watch(dismissedUpdateProvider).value ?? '';
  if (known.isEmpty || known == dismissed || !isNewer(known, appVersion)) {
    return null;
  }
  return known;
});

/// Dismisses the Home update notice for one version (FR-31-33).
final dismissUpdateNoticeProvider = Provider<Future<void> Function(String)>(
  (ref) => (version) => ref
      .read(settingsRepositoryProvider)
      .write(updateNoticeDismissedKey, version),
);

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
    updateVersion: ref.watch(homeUpdateVersionProvider),
  );
});

/// Rows of the shown month and the one before, for the running line, the
/// category donut and the change versus last month (FR-17-06, FR-17-11).
final homeMonthTxsProvider = StreamProvider<
    ({
      List<LedgerTx> cur,
      List<LedgerTx> prev,
    })>((ref) {
  final m = ref.watch(homeMonthProvider);
  final p = m.previous;
  final repo = ref.watch(transactionRepositoryProvider);
  final usage = bookUsage(ref.watch(bookProvider));
  return combineLatest<({List<LedgerTx> cur, List<LedgerTx> prev})>(
    [
      repo.watch(
        LedgerFilter(fromMs: m.startMs, toMs: m.endMs - 1, usage: usage),
      ),
      repo.watch(
        LedgerFilter(fromMs: p.startMs, toMs: p.endMs - 1, usage: usage),
      ),
    ],
    (v) => (
      cur: v[0]! as List<LedgerTx>,
      prev: v[1]! as List<LedgerTx>,
    ),
  );
});

/// Bills, EMIs, insurance renewals, income and card dues in the coming days
/// (FR-17-09); filtered to 7 days by the widget.
final homeUpcomingProvider = Provider<List<UpcomingRow>>((ref) {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final today = Ist.dateOf(nowMs);
  final todayDay = Ist.dayOf(nowMs);
  final bills = ref.watch(billsProvider).value ?? const [];
  final cards = ref.watch(cardLimitsProvider).value ?? const [];
  return [
    for (final b in bills)
      UpcomingRow(
        name: b.name,
        amountMinor: b.amountMinor,
        days: b.nextDue.difference(today).inDays,
        kind: b.income
            ? UpcomingKind.income
            : b.loanKey != null
                ? UpcomingKind.emi
                : b.category == Category.insurance
                    ? UpcomingKind.insurance
                    : UpcomingKind.bill,
      ),
    for (final c in cards)
      if (!c.paid && c.owedMinor > 0 && c.dueDay != null)
        UpcomingRow(
          name: '${c.name} card bill',
          amountMinor: c.owedMinor,
          days: c.dueDay! - todayDay,
          kind: UpcomingKind.card,
        ),
  ];
});
