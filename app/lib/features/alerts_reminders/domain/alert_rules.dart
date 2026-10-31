import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_text.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/credit_cards/domain/card_reminder_plan.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Pure alert decisions (memory 21 sections 3 and 10). Each function takes
/// plain input values and returns [AlertDecision]s; nothing is posted or
/// stored here. Callers pass the already-alerted keys (FR-21-14, cap 300) and
/// post under a global lock (FR-21-19).
abstract final class AlertRules {
  /// Window of due-soon bills in days, inclusive (FR-21-06).
  static const billWindowDays = 3;

  /// Window of insurance renewals in days, inclusive (FR-21-07).
  static const renewalWindowDays = 7;

  /// Untracked changes announced only within this many days (FR-21-08).
  static const gapWindowDays = 14;

  /// At most this many gap alerts per run.
  static const maxGapAlertsPerRun = 3;

  /// Fixed notification id bases.
  static const newTransactionIdBase = 10000;
  static const balanceUpdatedId = 9000;
  static const cardBillIdBase = 30000;
  static const statementIdBase = 4000;

  /// Budget alerts for the month `yyyy-MM` (FR-21-05): per budget the single
  /// highest reached level of {user percent, 100} not yet alerted.
  /// Budgets with a non-positive limit are skipped (memory 21 Open Question
  /// 12 decision: Home and Analysis ignore them).
  static List<AlertDecision> budgetAlerts({
    required List<Budget> budgets,
    required Map<Category, int> spentByCategory,
    required int year,
    required int month,
    required AlertSettings settings,
    required Set<String> alerted,
  }) {
    final ym = '$year-${month.toString().padLeft(2, '0')}';
    final out = <AlertDecision>[];
    for (final b in budgets) {
      if (b.monthlyLimitMinor <= 0) continue;
      final used = spentByCategory[b.category] ?? 0;
      final hit = BudgetMath.pendingAlert(
        budget: b,
        usedMinor: used,
        alertPercent: settings.budgetAlertPercent,
        yearMonth: ym,
        alerted: alerted,
      );
      if (hit == null) continue;
      final left = b.monthlyLimitMinor - used;
      final label = b.category.label;
      out.add(
        AlertDecision(
          kind: AlertKind.budget,
          key: hit.key,
          channel: AlertChannel.budgetsBills,
          notificationId: AlertText.stableId(hit.key),
          title: hit.level >= 100
              ? '$label: budget used up'
              : '$label: ${hit.level}% of budget used',
          body: left > 0
              ? '${AlertText.money(used)} of '
                  '${AlertText.money(b.monthlyLimitMinor)} spent. '
                  '${AlertText.money(left)} left for '
                  '${AlertText.monthYear(year, month)}.'
              : '${AlertText.money(used)} spent against '
                  '${AlertText.money(b.monthlyLimitMinor)}, '
                  '${AlertText.money(-left)} over.',
          link: 'hisaab://budgets',
        ),
      );
    }
    return out;
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Low-balance bill alerts (FR-21-06): non-income items due in 0..3 days
  /// whose paying bank account has a known balance below the amount, once
  /// per (name, due date).
  static List<AlertDecision> lowBalanceBillAlerts({
    required List<BillDueInput> bills,
    required DateTime today,
    required Set<String> alerted,
  }) {
    final out = <AlertDecision>[];
    for (final r in bills) {
      final days = daysBetween(today, r.nextDue);
      if (days < 0 || days > billWindowDays) continue;
      final label = r.accountLabel;
      final balance = r.accountBalanceMinor;
      if (label == null || !r.accountIsBank || balance == null) continue;
      if (balance >= r.amountMinor) continue;
      final key = 'bill:${r.name}:${_date(r.nextDue)}';
      if (alerted.contains(key)) continue;
      final amount = AlertText.money(r.amountMinor);
      out.add(
        AlertDecision(
          kind: AlertKind.lowBalanceBill,
          key: key,
          channel: AlertChannel.budgetsBills,
          notificationId: AlertText.stableId(key),
          title: switch (days) {
            0 => '${r.name} $amount due today',
            1 => '${r.name} $amount due tomorrow',
            _ => '${r.name} $amount due in $days days',
          },
          body: '$label ••${r.accountLast4} has ${AlertText.money(balance)}. '
              "Add ${AlertText.money(r.amountMinor - balance)} so it doesn't "
              'bounce.',
          link: 'hisaab://bills',
        ),
      );
    }
    return out;
  }

  /// Insurance renewal alerts (FR-21-07): non-monthly policies due in 0..7
  /// days, once per (insurer, due date). Wording fix: "in 1 day" (memory 21
  /// Open Question 6).
  static List<AlertDecision> renewalAlerts({
    required List<RenewalInput> policies,
    required DateTime today,
    required Set<String> alerted,
  }) {
    final out = <AlertDecision>[];
    for (final p in policies) {
      final days = daysBetween(today, p.nextDue);
      if (days < 0 || days > renewalWindowDays) continue;
      final key = 'renewal:${p.insurer}:${_date(p.nextDue)}';
      if (alerted.contains(key)) continue;
      out.add(
        AlertDecision(
          kind: AlertKind.insuranceRenewal,
          key: key,
          channel: AlertChannel.budgetsBills,
          notificationId: AlertText.stableId(key),
          title: days == 0
              ? '${p.kindLabel} insurance renews today'
              : '${p.kindLabel} insurance renews in $days '
                  '${days == 1 ? 'day' : 'days'}',
          body: '${p.insurer}: last premium '
              '${AlertText.money(p.premiumMinor)} on ${_date(p.lastPaid)}. '
              'Renew in time to stay covered.',
          link: 'hisaab://bills',
        ),
      );
    }
    return out;
  }

  /// Untracked-change alerts (FR-21-08): needs transaction notifications on;
  /// gaps ending within 14 days of [nowMs], at most 3 per run, once each.
  static List<AlertDecision> gapAlerts({
    required List<GapInput> gaps,
    required int nowMs,
    required AlertSettings settings,
    Set<String> alerted = const {},
  }) {
    if (!settings.transactionNotifications) return const [];
    final recent = nowMs - gapWindowDays * 86400000;
    final out = <AlertDecision>[];
    for (final g in gaps.where((g) => g.toTimeMs >= recent)) {
      if (out.length >= maxGapAlertsPerRun) break;
      final key = 'gap:${g.key}';
      if (alerted.contains(key)) continue;
      final amount = AlertText.money(g.deltaMinor.abs());
      final who = g.accountLabel;
      final text = g.card && g.moneyLeft
          ? '$who: $amount of limit used with no message. Add it?'
          : g.card
              ? '$who: $amount of limit freed with no message. Add it?'
              : g.moneyLeft
                  ? '$who: $amount left the account with no message. Add it?'
                  : '$who: $amount came in with no message. Add it?';
      out.add(
        AlertDecision(
          kind: AlertKind.untrackedChange,
          key: key,
          channel: AlertChannel.budgetsBills,
          notificationId: AlertText.stableId(key),
          title: 'Untracked change',
          body: text,
          link: 'hisaab://account/${g.accountId}',
        ),
      );
    }
    return out;
  }

  /// Card bill reminders (FR-21-09, FR-21-10) at [todayEpochDay]. Uses
  /// `CardReminderPlan` (stages 5, 2, 0, overdue; most urgent only; none
  /// after 7 days overdue, paid or snoozed). Cancels when the card is not
  /// billed or has no due day, or when no stage is due and the bill is paid.
  static List<AlertDecision> cardBillAlerts({
    required List<CardBillInput> cards,
    required int todayEpochDay,
    required AlertSettings settings,
  }) {
    final out = <AlertDecision>[];
    for (final c in cards) {
      final id = cardBillIdBase + c.cardId * 3;
      final billed = c.billedMinor;
      final due = c.dueEpochDay;
      if (billed == null || billed <= 0 || due == null) {
        out.add(
          AlertDecision.cancel(kind: AlertKind.cardBill, notificationId: id),
        );
        continue;
      }
      if (!settings.cardDueReminders) continue;
      final stage = CardReminderPlan.next(
        today: todayEpochDay,
        due: due,
        sent: c.sent,
        paid: c.paid,
        snoozedUntilDay: c.snoozedUntilEpochDay,
      );
      if (stage == null) {
        if (c.paid) {
          out.add(
            AlertDecision.cancel(kind: AlertKind.cardBill, notificationId: id),
          );
        }
        continue;
      }
      final days = due - todayEpochDay;
      final dueDate = fromEpochDay(due);
      final min = c.minDueMinor;
      final amount = AlertText.money(billed);
      final payBy = '${dueDate.day} ${_short[dueDate.month - 1]}';
      out.add(
        AlertDecision(
          kind: AlertKind.cardBill,
          key: '',
          channel: AlertChannel.budgetsBills,
          notificationId: id,
          title: days < 0
              ? '${c.name} bill overdue'
              : days == 0
                  ? '${c.name} bill due today'
                  : days == 1
                      ? '${c.name} bill due tomorrow'
                      : '${c.name} bill due in $days days',
          body: '${c.estimated ? 'About $amount' : amount} · pay by $payBy.'
              '${min != null ? ' Minimum ${AlertText.money(min)}.' : ''}',
          link: 'hisaab://account/${c.cardId}',
          stage: stage,
          actions: [
            AlertAction(
              id: 'com.hisaab.app.CARD_DUE_PAID',
              label: 'Mark paid',
              payload: {'cardId': '${c.cardId}', 'dueEpochDay': '$due'},
            ),
            AlertAction(
              id: 'com.hisaab.app.CARD_DUE_SNOOZE',
              label: 'Remind tomorrow',
              payload: {'cardId': '${c.cardId}', 'dueEpochDay': '$due'},
            ),
          ],
        ),
      );
    }
    return out;
  }

  static const _short = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  /// New-transaction notification (FR-21-02, FR-21-03): only for newly
  /// inserted, non-transfer rows with transaction notifications on.
  /// [usedMostFirst] are the categories used most for this type in the last
  /// 90 days.
  static AlertDecision? newTransactionAlert({
    required int txId,
    required int amountMinor,
    required String currency,
    required bool isCredit,
    required String who,
    required Category category,
    required bool inserted,
    required bool isTransfer,
    required AlertSettings settings,
    String? last4,
    String bank = '',
    List<Category> usedMostFirst = const [],
    List<Category> merchantFirst = const [],
  }) {
    if (!inserted || isTransfer || !settings.transactionNotifications) {
      return null;
    }
    final amount = AlertText.money(
      amountMinor,
      showPaise: true,
      currency: currency,
    );
    final alts = alternativeCategories(
      current: category,
      isCredit: isCredit,
      usedMostFirst: usedMostFirst,
      merchantFirst: merchantFirst,
    );
    final id = newTransactionIdBase + txId;
    return AlertDecision(
      kind: AlertKind.newTransaction,
      key: '',
      channel: AlertChannel.newTransactions,
      notificationId: id,
      title: isCredit ? 'Received $amount from $who' : 'Spent $amount at $who',
      body: 'What was this for? · $bank'
          '${(last4 != null && last4.isNotEmpty) ? ' ••$last4' : ''}\n'
          'Filed under ${category.label}',
      link: 'hisaab://transaction/$txId',
      actions: [
        for (final c in alts)
          AlertAction(
            id: 'category',
            label: c.label,
            payload: {'txId': '$txId', 'category': c.name},
          ),
        AlertAction(
          id: 'more',
          label: 'More…',
          payload: {'txId': '$txId'},
        ),
      ],
    );
  }

  /// Confirmation that replaces the notification after a button tap (FR-21-03).
  static AlertDecision categorySavedAlert({
    required int txId,
    required Category category,
  }) =>
      AlertDecision(
        kind: AlertKind.newTransaction,
        key: '',
        channel: AlertChannel.newTransactions,
        notificationId: newTransactionIdBase + txId,
        title: 'Saved as ${category.label}',
        body: 'DhanKosh will use it for this merchant from now on.',
        link: '',
        timeoutMs: 4000,
      );

  static const List<Category> _creditDefaults = [
    Category.salary,
    Category.refund,
    Category.income,
    Category.transfer,
  ];
  static const List<Category> _debitDefaults = [
    Category.food,
    Category.groceries,
    Category.shopping,
    Category.transport,
    Category.bills,
  ];

  /// Up to 2 best guesses (FR-21-03): this merchant's earlier categories
  /// first, then the most-used for the type, then defaults; distinct,
  /// excluding the current category and OTHER. "More…" follows them.
  static List<Category> alternativeCategories({
    required Category current,
    required bool isCredit,
    required List<Category> usedMostFirst,
    List<Category> merchantFirst = const [],
    int max = 2,
  }) {
    final out = <Category>[];
    for (final c in [
      ...merchantFirst,
      ...usedMostFirst,
      ...(isCredit ? _creditDefaults : _debitDefaults),
    ]) {
      if (c == current || c == Category.other || out.contains(c)) continue;
      out.add(c);
      if (out.length == max) break;
    }
    return out;
  }

  /// Every category offered by the "Change category" sheet (FR-21-22):
  /// income-side for credits, the rest for spends; [current] always listed.
  static List<Category> categoriesFor({
    required bool isCredit,
    required Category current,
  }) {
    const income = {
      Category.salary,
      Category.income,
      Category.refund,
      Category.gifts,
      Category.investment,
      Category.transfer,
      Category.other,
    };
    return [
      for (final c in Category.values)
        if (c == current ||
            (isCredit
                ? income.contains(c)
                : !const {
                    Category.salary,
                    Category.income,
                    Category.refund,
                  }.contains(c)))
          c,
    ];
  }

  /// One merged "balance updated" notification (FR-21-04), or null when
  /// [gaps] is empty or transaction notifications are off. The once-per-IST-
  /// day-per-account filtering is the caller's.
  static AlertDecision? balanceUpdatedAlert({
    required List<BalanceGapInput> gaps,
    required AlertSettings settings,
  }) {
    if (gaps.isEmpty || !settings.transactionNotifications) return null;
    final lines = [
      for (final g in gaps)
        '${g.label} · ${AlertText.money(g.unexplainedMinor.abs())} not explained',
    ];
    final single = gaps.length == 1;
    return AlertDecision(
      kind: AlertKind.balanceUpdated,
      key: '',
      channel: AlertChannel.newTransactions,
      notificationId: balanceUpdatedId,
      title: single
          ? '${gaps.first.label} updated'
          : '${gaps.length} balances updated',
      body: single
          ? '${AlertText.money(gaps.first.unexplainedMinor.abs())} not '
              'explained · transactions may be missing'
          : lines.join(' · '),
      link: '',
    );
  }

  /// Password-protected statement notice (FR-21-12); never shows figures.
  static AlertDecision statementLockedAlert({
    required int statementId,
    String? bank,
  }) =>
      AlertDecision(
        kind: AlertKind.statementLocked,
        key: '',
        channel: AlertChannel.statements,
        notificationId: statementIdBase + statementId,
        title: (bank == null || bank.isEmpty)
            ? 'A statement detected'
            : '$bank statement detected',
        body: "It's password protected. Tap to enter the password so DhanKosh "
            'can read it.',
        link: 'hisaab://statements?unlock=$statementId',
      );

  static String _mon(int m) => AlertText.monthNames[m - 1].substring(0, 3);

  /// Monday (UTC-midnight IST day) of the last completed week at [today]
  /// (FR-21-21). A Monday gives the week that ended yesterday.
  static DateTime lastWeekStart(DateTime today) =>
      DateTime.utc(today.year, today.month, today.day)
          .subtract(Duration(days: today.weekday - 1 + 7));

  /// Dedupe key of the summary for the week starting [monday].
  static String weeklyKey(DateTime monday) =>
      'weekly:${monday.year}-${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';

  /// Weekly summary of the last completed week against the one before
  /// (FR-21-21). Null when the toggle is off, nothing was spent in either
  /// week, or this week's summary was already sent (once per week).
  static AlertDecision? weeklySummary({
    required DateTime today,
    required WeekSpend week,
    required WeekSpend previous,
    required AlertSettings settings,
    required Set<String> alerted,
  }) {
    if (!settings.weeklySummary) return null;
    final monday = lastWeekStart(today);
    final key = weeklyKey(monday);
    if (alerted.contains(key)) return null;
    if (week.spentMinor <= 0 && previous.spentMinor <= 0) return null;
    final sunday = monday.add(const Duration(days: 6));
    final range = monday.month == sunday.month
        ? '${monday.day}-${sunday.day} ${_mon(sunday.month)}'
        : '${monday.day} ${_mon(monday.month)}-'
            '${sunday.day} ${_mon(sunday.month)}';
    final diff = week.spentMinor - previous.spentMinor;
    final String cmp;
    if (previous.spentMinor <= 0) {
      cmp = 'Nothing was spent the week before.';
    } else if (diff == 0) {
      cmp = 'Same as the week before.';
    } else {
      cmp = '${AlertText.money(diff.abs())} '
          '${diff > 0 ? 'more' : 'less'} than the week before.';
    }
    final top = week.topCategory;
    final topText = top == null || week.topCategoryMinor <= 0
        ? ''
        : ' Top: ${top.label} ${AlertText.money(week.topCategoryMinor)}.';
    return AlertDecision(
      kind: AlertKind.weeklySummary,
      key: key,
      channel: AlertChannel.budgetsBills,
      notificationId: AlertText.stableId(key),
      title: 'Week $range: ${AlertText.money(week.spentMinor)} spent',
      body: '$cmp$topText',
      link: 'hisaab://home',
    );
  }

  /// Spend and top category of [txs] inside [fromMs, toMs): debits that are
  /// not transfers or review rows, in INR (FR-21-21).
  static WeekSpend weekSpend(Iterable<LedgerTx> txs, int fromMs, int toMs) {
    final inRange =
        txs.where((t) => t.timestamp >= fromMs && t.timestamp < toMs).toList();
    // Headline total is cash basis (ADR-0011): card purchases excluded, card
    // bill payments included. The top category still sees card purchases.
    final total = SpendCalc.totals(inRange, context: txs.toList()).spentMinor;
    final by = <Category, int>{};
    for (final t in inRange) {
      if (t.needsReview || t.type != TransactionType.debit) continue;
      final inr = SpendCalc.rupees(t);
      by.update(t.category, (v) => v + inr, ifAbsent: () => inr);
    }
    Category? top;
    var topMinor = 0;
    for (final e in by.entries) {
      if (e.value > topMinor) {
        top = e.key;
        topMinor = e.value;
      }
    }
    return WeekSpend(
      spentMinor: total,
      topCategory: top,
      topCategoryMinor: topMinor,
    );
  }

  /// Dedupe key of the update notification for [version].
  static String updateKey(String version) => 'update:$version';

  /// One "DhanKosh x.y.z is available" notification per version (FR-31-34).
  /// Null when the toggle is off, [version] is not newer than [installed],
  /// or it was already announced.
  static AlertDecision? updateAvailable({
    required String version,
    required String installed,
    required AlertSettings settings,
    required Set<String> alerted,
  }) {
    if (!settings.updateAvailable || version.isEmpty) return null;
    if (!isNewer(version, installed)) return null;
    final key = updateKey(version);
    if (alerted.contains(key)) return null;
    return AlertDecision(
      kind: AlertKind.updateAvailable,
      key: key,
      channel: AlertChannel.budgetsBills,
      notificationId: AlertText.stableId(key),
      title: 'DhanKosh $version is available',
      body: 'Open About and updates to install it.',
      link: 'hisaab://updates',
    );
  }
}
