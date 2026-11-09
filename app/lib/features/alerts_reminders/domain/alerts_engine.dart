import 'dart:async';

import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerted_key_store.dart';
import 'package:hisaab/features/alerts_reminders/domain/card_reminder_state_store.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/domain/card_reminder_plan.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_repository.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/recurring_transactions/domain/bills_view.dart';
import 'package:hisaab/features/recurring_transactions/domain/price_change.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';
import 'package:parser_core/parser_core.dart';

/// Gathers inputs, runs [AlertRules] and posts the decisions (FR-21-05,
/// FR-21-06, FR-21-07, FR-21-13, FR-21-14, FR-21-16, FR-21-19).
///
/// Only decisions that need action are posted; informational ones
/// ([AlertDecision.logOnly]) go to the Activity log (FR-21-27).
///
/// Card reminders (FR-21-09, with `cards` and `cardState`) and new-transaction
/// notifications (FR-21-02, with `txs`) are wired; untracked-change alerts
/// (FR-21-08) are not yet.
class AlertsEngine {
  /// Creates the engine.
  AlertsEngine({
    required BudgetRepository budgets,
    required RecurringRepository recurring,
    required AccountRepository accounts,
    required AlertedKeyStore alerted,
    required AlertPoster poster,
    required AlertSettingsRepository settings,
    TransactionRepository? txs,
    ActivityLogger? activity,
    Future<List<CardLimit>> Function()? cards,
    CardReminderStateStore? cardState,
    Future<String?> Function()? updateVersion,
    Future<List<Recurring>> Function()? bills,
    Future<int> Function(DateTime today)? autoPost,
    String installedVersion = '0.0.0',
    int Function()? nowMs,
  })  : _budgets = budgets,
        _recurring = recurring,
        _accounts = accounts,
        _alerted = alerted,
        _poster = poster,
        _settings = settings,
        _txs = txs,
        _activity = activity,
        _cards = cards,
        _cardState = cardState,
        _updateVersion = updateVersion,
        _bills = bills,
        _autoPost = autoPost,
        _installed = installedVersion,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final BudgetRepository _budgets;
  final RecurringRepository _recurring;
  final AccountRepository _accounts;
  final AlertedKeyStore _alerted;
  final Future<List<Recurring>> Function()? _bills;
  final Future<int> Function(DateTime today)? _autoPost;
  final AlertPoster _poster;
  final AlertSettingsRepository _settings;
  final TransactionRepository? _txs;
  final ActivityLogger? _activity;
  final Future<List<CardLimit>> Function()? _cards;
  final CardReminderStateStore? _cardState;

  /// New-transaction alerts only for rows created this recently (FR-21-02).
  static const int newTxWindowMs = 30 * 60 * 1000;

  /// Runs the throttled update check and returns the newest known version
  /// (FR-31-34); null when none or no checker is wired.
  final Future<String?> Function()? _updateVersion;
  final String _installed;
  final int Function() _nowMs;

  static const _istOffsetMs = 19800000;

  DateTime _today() {
    final ist = DateTime.fromMillisecondsSinceEpoch(
      _nowMs() + _istOffsetMs,
      isUtc: true,
    );
    return DateTime.utc(ist.year, ist.month, ist.day);
  }

  Future<void> _tail = Future.value();

  /// Runs every check once; serialised (FR-21-19), each check isolated
  /// (FR-21-13). Returns the number of notifications posted. Never throws.
  Future<int> run() {
    final next = _tail.then((_) => _runLocked());
    _tail = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  Future<int> _runLocked() async {
    var posted = 0;
    // Activity-log events of this run: code -> (count, notified) (FR-21-27).
    final events = <String, (int, bool)>{};
    try {
      // With notifications blocked nothing is posted, but informational
      // events still reach the log.
      final enabled = await _poster.areEnabled();
      final settings = await _settings.read();
      final ist = DateTime.fromMillisecondsSinceEpoch(
        _nowMs() + _istOffsetMs,
        isUtc: true,
      );
      final today = DateTime.utc(ist.year, ist.month, ist.day);
      // Regular payments the user asked to add themselves (ADR-0013).
      try {
        await _autoPost?.call(today);
      } on Object {
        // A failed auto-post never stops the alert checks.
      }
      for (final check in <Future<List<AlertDecision>> Function()>[
        () => _budgetDecisions(settings, ist),
        () => _billDecisions(today),
        () => _lowBalanceDecisions(today),
        () => _priceDecisions(settings, today),
        () => _billReminderDecisions(settings, today, ist.hour),
        () => _cardDecisions(settings, today),
        () => _newTxDecisions(settings),
        () => _renewalDecisions(today),
        () => _weeklyDecisions(settings, today),
        () => _dailyDecisions(settings, today, ist.hour),
        () => _updateDecisions(settings),
      ]) {
        try {
          for (final d in await check()) {
            if (await _deliver(d, enabled: enabled, events: events)) {
              posted++;
            }
          }
        } on Object catch (e) {
          // One failing check must not stop the others.
          AppLog.instance.error(
            LogCategory.background,
            'alerts.check_failed',
            fields: errorFields(e),
          );
        }
      }
    } on Object catch (e) {
      // Never throw into callers.
      AppLog.instance.error(
        LogCategory.background,
        'alerts.run_failed',
        fields: errorFields(e),
      );
    }
    await _recordEvents(events);
    AppLog.instance.info(
      LogCategory.background,
      'alerts.done',
      fields: {'posted': posted},
    );
    return posted;
  }

  /// Card bill reminders at 5 days, 2 days, due day and overdue (FR-21-09).
  Future<List<AlertDecision>> _cardDecisions(
    AlertSettings settings,
    DateTime today,
  ) async {
    final source = _cards;
    final state = _cardState;
    if (source == null || state == null) return const [];
    final day = epochDayOf(today);
    final inputs = <CardBillInput>[];
    for (final c in await source()) {
      final due = c.dueDay;
      final rec = due == null ? null : await state.read(c.id, due);
      inputs.add(
        CardBillInput(
          cardId: c.id,
          name: c.name,
          billedMinor: c.billedMinor,
          dueEpochDay: due,
          minDueMinor: c.minDueMinor,
          estimated: c.estimated,
          paid: c.paid || (rec?.paid ?? false),
          sent: {
            for (final s in DueStage.values)
              if (rec?.stagesSent.contains(s.name) ?? false) s,
          },
          snoozedUntilEpochDay: rec?.snoozedUntilEpochDay,
        ),
      );
    }
    return AlertRules.cardBillAlerts(
      cards: inputs,
      todayEpochDay: day,
      settings: settings,
    );
  }

  /// "Rs X at Y" for rows ingested in the last 30 minutes (FR-21-02).
  Future<List<AlertDecision>> _newTxDecisions(AlertSettings settings) async {
    final txs = _txs;
    if (txs == null || !settings.transactionNotifications) return const [];
    final rows = await txs.watchRecent(200).first;
    final alerted = await _alerted.all();
    final now = _nowMs();
    List<Category> usedMost({required bool credit}) {
      final counts = <Category, int>{};
      for (final r in rows) {
        if ((r.type == TransactionType.credit) != credit) continue;
        counts.update(r.category, (n) => n + 1, ifAbsent: () => 1);
      }
      final keys = counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      return keys;
    }

    // Categories filed for the same merchant on earlier rows, most used first
    // (the merchant rule's learned category).
    List<Category> merchantUsed(LedgerTx tx) {
      if (tx.merchant == null) return const [];
      final counts = <Category, int>{};
      for (final r in rows) {
        if (r.id == tx.id || r.merchant != tx.merchant) continue;
        counts.update(r.category, (n) => n + 1, ifAbsent: () => 1);
      }
      return counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    }

    final out = <AlertDecision>[];
    for (final r in rows) {
      final key = 'tx:${r.id}';
      if (now - r.createdAt > newTxWindowMs || alerted.contains(key)) continue;
      if (r.duplicateOfId != null || r.needsReview) continue;
      final credit = r.type == TransactionType.credit;
      final d = AlertRules.newTransactionAlert(
        txId: r.id,
        amountMinor: r.amountMinor,
        currency: r.currency,
        isCredit: credit,
        who: r.title,
        category: r.category,
        inserted: true,
        isTransfer: r.type == TransactionType.transfer ||
            r.type == TransactionType.investment ||
            r.category == Category.transfer,
        settings: settings,
        last4: r.accountLast4,
        usedMostFirst: usedMost(credit: credit),
        merchantFirst: merchantUsed(r),
        bank: r.bankName,
      );
      if (d == null) continue;
      out.add(
        AlertDecision(
          kind: d.kind,
          key: key,
          channel: d.channel,
          notificationId: d.notificationId,
          title: d.title,
          body: d.body,
          link: d.link,
          actions: d.actions,
        ),
      );
    }
    return out;
  }

  /// One Activity-log entry per event code of the run (FR-21-27); counts and
  /// codes only.
  Future<void> _recordEvents(Map<String, (int, bool)> events) async {
    final log = _activity;
    if (log == null) return;
    final at = DateTime.fromMillisecondsSinceEpoch(_nowMs());
    for (final e in events.entries) {
      await log.record(
        ActivityEntry.alert(
          at: at,
          kind: e.key,
          count: e.value.$1,
          notified: e.value.$2,
        ),
      );
    }
  }

  void _count(Map<String, (int, bool)> events, AlertDecision d) {
    final key = d.logCode;
    events[key] = ((events[key]?.$1 ?? 0) + 1, !d.logOnly);
  }

  Future<bool> _deliver(
    AlertDecision d, {
    required bool enabled,
    required Map<String, (int, bool)> events,
  }) async {
    if (d.logOnly) {
      // Informational: no notification; the key keeps it to once.
      if (d.key.isNotEmpty) await _alerted.add(d.key, _nowMs());
      _count(events, d);
      return false;
    }
    if (!enabled) return false;
    if (d.cancel) {
      await _poster.cancel(d.notificationId);
      return false;
    }
    final ok = await _poster.post(d);
    if (!ok) {
      AppLog.instance.warn(
        LogCategory.background,
        'alerts.post_failed',
        fields: {'kind': d.kind.name},
      );
    }
    // Key stored only after a successful post (memory 21 Open Question 1).
    if (ok && d.key.isNotEmpty) await _alerted.add(d.key, _nowMs());
    if (ok) _count(events, d);
    final stage = d.stage;
    final state = _cardState;
    if (ok && stage != null && state != null && d.actions.isNotEmpty) {
      final p = d.actions.first.payload;
      final id = int.tryParse(p['cardId'] ?? '');
      final due = int.tryParse(p['dueEpochDay'] ?? '');
      if (id != null && due != null) {
        for (final s in CardReminderPlan.markSent(stage)) {
          await state.markSent(
            id,
            due,
            s.name,
            todayEpochDay: epochDayOf(_today()),
          );
        }
      }
    }
    return ok;
  }

  Future<List<AlertDecision>> _budgetDecisions(
    AlertSettings settings,
    DateTime ist,
  ) async {
    final budgets = await _budgets.all();
    if (budgets.isEmpty) return const [];
    final from =
        DateTime.utc(ist.year, ist.month).millisecondsSinceEpoch - _istOffsetMs;
    final to = DateTime.utc(ist.year, ist.month + 1).millisecondsSinceEpoch -
        _istOffsetMs -
        1;
    return AlertRules.budgetAlerts(
      budgets: budgets,
      spentByCategory: await _budgets.categoryTotals(from, to),
      year: ist.year,
      month: ist.month,
      settings: settings,
      alerted: await _alerted.all(),
    );
  }

  /// "DhanKosh x.y.z is available", once per version (FR-31-34).
  Future<List<AlertDecision>> _updateDecisions(AlertSettings settings) async {
    final source = _updateVersion;
    if (source == null || !settings.updateAvailable) return const [];
    final version = await source();
    if (version == null) return const [];
    final d = AlertRules.updateAvailable(
      version: version,
      installed: _installed,
      settings: settings,
      alerted: await _alerted.all(),
    );
    return d == null ? const [] : [d];
  }

  /// Weekly summary (FR-21-21): last completed Monday-Sunday week against
  /// the week before, once per week through the alerted keys.
  Future<List<AlertDecision>> _weeklyDecisions(
    AlertSettings settings,
    DateTime today,
  ) async {
    final txs = _txs;
    if (!settings.weeklySummary || txs == null) return const [];
    final monday = AlertRules.lastWeekStart(today);
    final alerted = await _alerted.all();
    if (alerted.contains(AlertRules.weeklyKey(monday))) return const [];
    int ms(DateTime d) => d.millisecondsSinceEpoch - _istOffsetMs;
    final prevMonday = monday.subtract(const Duration(days: 7));
    final end = monday.add(const Duration(days: 7));
    final rows = await txs
        .watch(LedgerFilter(fromMs: ms(prevMonday), toMs: ms(end)))
        .first;
    final d = AlertRules.weeklySummary(
      today: today,
      week: AlertRules.weekSpend(rows, ms(monday), ms(end)),
      previous: AlertRules.weekSpend(rows, ms(prevMonday), ms(monday)),
      settings: settings,
      alerted: alerted,
    );
    return d == null ? const [] : [d];
  }

  Future<List<AlertDecision>> _dailyDecisions(
    AlertSettings settings,
    DateTime today,
    int hour,
  ) async {
    final txs = _txs;
    if (!settings.dailySummary || txs == null || hour < 21) return const [];
    final from = today.millisecondsSinceEpoch - _istOffsetMs;
    final rows = await txs
        .watch(LedgerFilter(fromMs: from, toMs: from + 86400000))
        .first;
    final counted = rows.where(SpendCalc.counts).toList();
    final debits = counted.where((t) => t.type == TransactionType.debit);
    final d = AlertRules.dailySummary(
      today: today,
      hour: hour,
      spentMinor: AlertRules.weekSpend(rows, from, from + 86400000).spentMinor,
      paymentCount: debits.length,
      uncategorisedCount:
          debits.where((t) => t.category == Category.other).length,
      settings: settings,
      alerted: await _alerted.all(),
    );
    return d == null ? const [] : [d];
  }

  static DateTime _nextDue(RecurringItem r, DateTime today) {
    DateTime at(int y, int m) {
      final last = DateTime.utc(y, m + 1, 0).day;
      return DateTime.utc(y, m, r.dayOfMonth > last ? last : r.dayOfMonth);
    }

    if (r.frequency == RecurringFrequency.yearly) {
      final m = r.month ?? 1;
      final d = at(today.year, m);
      return d.isBefore(today) ? at(today.year + 1, m) : d;
    }
    final d = at(today.year, today.month);
    return d.isBefore(today) ? at(today.year, today.month + 1) : d;
  }

  /// The last 45 days of ledger rows, to see what is already paid.
  Future<List<LedgerTx>> _recentTxs(DateTime today) async {
    final txs = _txs;
    if (txs == null) return const [];
    final from = today.subtract(const Duration(days: 45));
    return await txs
        .watch(LedgerFilter(fromMs: from.millisecondsSinceEpoch - _istOffsetMs))
        .first;
  }

  Future<List<AlertDecision>> _billDecisions(DateTime today) async {
    final items = (await _recurring.all()).where((r) => !r.income).toList();
    if (items.isEmpty) return const [];
    final accounts = {
      for (final a in await _accounts.watchVisible().first) a.id: a,
    };
    final recent = await _recentTxs(today);
    final bills = <BillDueInput>[];
    for (final r in items) {
      // Already paid for this due date: no "coming up" notice (FR-21-32).
      final due = _nextDue(r, today);
      if (RecurringDetector.paymentFor(r, due, today, recent) != null) continue;
      var acc = r.accountId == null ? null : accounts[r.accountId];
      if (acc?.mergedIntoId != null) acc = accounts[acc!.mergedIntoId];
      bills.add(
        BillDueInput(
          name: r.name,
          amountMinor: r.amountMinor,
          nextDue: _nextDue(r, today),
          accountLabel: acc == null ? null : _label(acc),
          accountLast4: acc?.last4 ?? '',
          accountBalanceMinor:
              acc?.latestBalanceMinor ?? acc?.manualBalanceMinor,
          accountIsBank: acc?.kind == AccountKind.account,
        ),
      );
    }
    return AlertRules.lowBalanceBillAlerts(
      bills: bills,
      today: today,
      alerted: await _alerted.all(),
    );
  }

  Future<List<AlertDecision>> _billReminderDecisions(
    AlertSettings settings,
    DateTime today,
    int hour,
  ) async {
    final source = _bills;
    if (source == null || !settings.billReminders || hour < 8) return const [];
    final inputs = <BillReminderInput>[];
    for (final r in await source()) {
      // Only what the user declared: own items and loan EMIs.
      if (r.income || (r.manualId == null && r.loanKey == null)) continue;
      // The account is a soft reference; use it only while it exists.
      final id = r.accountId;
      final acc = id == null ? null : await _accounts.byId(id);
      inputs.add(
        BillReminderInput(
          name: r.name,
          amountMinor: r.amountMinor,
          nextDue: r.nextDue,
          categoryName: r.category.name,
          accountId: acc?.id,
          paid: BillsView.paid(r, today),
        ),
      );
    }
    return AlertRules.billReminders(
      bills: inputs,
      today: today,
      hour: hour,
      settings: settings,
      alerted: await _alerted.all(),
    );
  }

  Future<List<AlertDecision>> _priceDecisions(
    AlertSettings settings,
    DateTime today,
  ) async {
    final txs = _txs;
    if (txs == null || !settings.billReminders) return const [];
    final from = today.subtract(const Duration(days: 130));
    final rows = await txs
        .watch(
          LedgerFilter(fromMs: from.millisecondsSinceEpoch - _istOffsetMs),
        )
        .first;
    return AlertRules.priceChangeAlerts(
      changes: PriceChanges.detect(rows, today),
      settings: settings,
      alerted: await _alerted.all(),
    );
  }

  Future<List<AlertDecision>> _lowBalanceDecisions(DateTime today) async {
    final ms = today.millisecondsSinceEpoch - _istOffsetMs;
    final rows = await _accounts
        .watchWithActivity(monthStartMs: ms, monthEndMs: ms + 86400000)
        .first;
    final inputs = <LowBalanceInput>[
      for (final r in rows)
        if (r.account.lowBalanceMinor != null &&
            !r.account.hidden &&
            r.account.mergedIntoId == null &&
            r.currentBalanceMinor != null)
          LowBalanceInput(
            id: r.account.id,
            label: r.account.label,
            balanceMinor: r.currentBalanceMinor!,
            thresholdMinor: r.account.lowBalanceMinor!,
          ),
    ];
    if (inputs.isEmpty) return const [];
    return AlertRules.lowBalanceAccountAlerts(
      accounts: inputs,
      today: today,
      alerted: await _alerted.all(),
    );
  }

  Future<List<AlertDecision>> _renewalDecisions(DateTime today) async {
    final recent = await _recentTxs(today);
    final policies = <RenewalInput>[
      for (final r in await _recurring.all())
        if (!r.income &&
            r.frequency == RecurringFrequency.yearly &&
            r.category == Category.insurance &&
            RecurringDetector.paymentFor(
                  r,
                  _nextDue(r, today),
                  today,
                  recent,
                ) ==
                null)
          RenewalInput(
            insurer: r.name,
            kindLabel: r.name,
            premiumMinor: r.amountMinor,
            lastPaid: DateTime.utc(
              _nextDue(r, today).year - 1,
              _nextDue(r, today).month,
              _nextDue(r, today).day,
            ),
            nextDue: _nextDue(r, today),
          ),
    ];
    if (policies.isEmpty) return const [];
    return AlertRules.renewalAlerts(
      policies: policies,
      today: today,
      alerted: await _alerted.all(),
    );
  }

  static String _label(Account a) {
    final n = a.nickname;
    return n != null && n.trim().isNotEmpty ? n : a.bankName;
  }
}
