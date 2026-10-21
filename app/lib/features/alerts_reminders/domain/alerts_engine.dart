import 'dart:async';

import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerted_key_store.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_repository.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_repository.dart';
import 'package:parser_core/parser_core.dart';

/// Gathers inputs, runs [AlertRules] and posts the decisions (FR-21-05,
/// FR-21-06, FR-21-07, FR-21-13, FR-21-14, FR-21-16, FR-21-19).
///
/// Card reminders (FR-21-09) and untracked-change alerts (FR-21-08) are not
/// wired yet; their rules exist in [AlertRules].
class AlertsEngine {
  /// Creates the engine.
  AlertsEngine({
    required BudgetRepository budgets,
    required RecurringRepository recurring,
    required AccountRepository accounts,
    required AlertedKeyStore alerted,
    required AlertPoster poster,
    required AlertSettingsRepository settings,
    int Function()? nowMs,
  })  : _budgets = budgets,
        _recurring = recurring,
        _accounts = accounts,
        _alerted = alerted,
        _poster = poster,
        _settings = settings,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final BudgetRepository _budgets;
  final RecurringRepository _recurring;
  final AccountRepository _accounts;
  final AlertedKeyStore _alerted;
  final AlertPoster _poster;
  final AlertSettingsRepository _settings;
  final int Function() _nowMs;

  static const _istOffsetMs = 19800000;

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
    try {
      if (!await _poster.areEnabled()) return 0;
      final settings = await _settings.read();
      final ist = DateTime.fromMillisecondsSinceEpoch(
        _nowMs() + _istOffsetMs,
        isUtc: true,
      );
      final today = DateTime.utc(ist.year, ist.month, ist.day);
      for (final check in <Future<List<AlertDecision>> Function()>[
        () => _budgetDecisions(settings, ist),
        () => _billDecisions(today),
        () => _renewalDecisions(today),
      ]) {
        try {
          for (final d in await check()) {
            if (await _deliver(d)) posted++;
          }
        } on Object {
          // One failing check must not stop the others.
        }
      }
    } on Object {
      // Never throw into callers.
    }
    return posted;
  }

  Future<bool> _deliver(AlertDecision d) async {
    if (d.cancel) {
      await _poster.cancel(d.notificationId);
      return false;
    }
    final ok = await _poster.post(d);
    // Key stored only after a successful post (memory 21 Open Question 1).
    if (ok && d.key.isNotEmpty) await _alerted.add(d.key, _nowMs());
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

  Future<List<AlertDecision>> _billDecisions(DateTime today) async {
    final items = (await _recurring.all()).where((r) => !r.income).toList();
    if (items.isEmpty) return const [];
    final accounts = {
      for (final a in await _accounts.watchVisible().first) a.id: a,
    };
    final bills = <BillDueInput>[];
    for (final r in items) {
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

  Future<List<AlertDecision>> _renewalDecisions(DateTime today) async {
    final policies = <RenewalInput>[
      for (final r in await _recurring.all())
        if (!r.income &&
            r.frequency == RecurringFrequency.yearly &&
            r.category == Category.insurance)
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
