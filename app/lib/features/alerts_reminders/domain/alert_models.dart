import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:parser_core/parser_core.dart';

/// Notification channels (FR-21-01): ids `new_transactions`,
/// `budgets_bills`, `statements`.
enum AlertChannel {
  newTransactions('new_transactions'),
  budgetsBills('budgets_bills'),
  statements('statements');

  const AlertChannel(this.id);

  final String id;
}

/// What an alert is about.
enum AlertKind {
  newTransaction,
  balanceUpdated,
  budget,
  lowBalanceBill,
  insuranceRenewal,
  untrackedChange,
  cardBill,
  statementLocked,
  weeklySummary,
  updateAvailable,
}

/// A notification button (FR-21-03, FR-21-10).
class AlertAction {
  const AlertAction({
    required this.id,
    required this.label,
    this.payload = const {},
  });

  final String id;
  final String label;
  final Map<String, String> payload;
}

/// One decision of the pure alert rules: post a notification, or cancel one
/// (card bill no longer billed or paid). Posting and persistence are done by
/// callers: record [key] in the alerted set only after a successful post
/// (memory 21 Open Question 1), and record [stage] with
/// `CardReminderPlan.markSent` for card bills.
class AlertDecision {
  const AlertDecision({
    required this.kind,
    required this.key,
    required this.channel,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.link,
    this.actions = const [],
    this.stage,
    this.timeoutMs,
    this.logOnly = false,
  }) : cancel = false;

  /// Cancel the notification with [notificationId].
  const AlertDecision.cancel({
    required this.kind,
    required this.notificationId,
    this.key = '',
  })  : channel = AlertChannel.budgetsBills,
        title = '',
        body = '',
        link = '',
        actions = const [],
        stage = null,
        timeoutMs = null,
        logOnly = false,
        cancel = true;

  final AlertKind kind;

  /// Dedupe key (`budget:`, `bill:`, `renewal:`, `gap:`; empty when none).
  final String key;
  final AlertChannel channel;
  final int notificationId;
  final String title;
  final String body;

  /// `hisaab://...` deep link (FR-21-15).
  final String link;
  final List<AlertAction> actions;

  /// Card-bill stage to mark sent after posting.
  final DueStage? stage;
  final int? timeoutMs;
  final bool cancel;

  /// Informational event that needs no action (FR-21-27): never posted, only
  /// written to the Activity log, and its [key] is stored so it happens once.
  final bool logOnly;

  /// Closed Activity-log code of this event (FR-21-27); no text or amounts.
  String get logCode =>
      logOnly && kind == AlertKind.budget ? 'budgetWarning' : kind.name;
}

/// Alert settings (FR-21-18).
class AlertSettings {
  const AlertSettings({
    this.transactionNotifications = true,
    this.budgetAlertPercent = 90,
    this.cardDueReminders = true,
    this.weeklySummary = false,
    this.updateAvailable = true,
  });

  /// Notify once per new app version, on by default (FR-31-34).
  final bool updateAvailable;

  /// Weekly summary notification, off by default (FR-21-21).
  final bool weeklySummary;

  final bool transactionNotifications;

  /// UI offers 80, 90 or 95.
  final int budgetAlertPercent;
  final bool cardDueReminders;
}

/// A bill or EMI due soon with its paying bank account already resolved
/// (merge map, then a debit card's linked account) by the caller
/// (FR-21-06). Money in paise; [nextDue] is a UTC-midnight day.
class BillDueInput {
  const BillDueInput({
    required this.name,
    required this.amountMinor,
    required this.nextDue,
    this.accountLabel,
    this.accountLast4 = '',
    this.accountBalanceMinor,
    this.accountIsBank = true,
  });

  final String name;
  final int amountMinor;
  final DateTime nextDue;

  /// Nickname or bank name; null when no paying account could be resolved.
  final String? accountLabel;
  final String accountLast4;
  final int? accountBalanceMinor;

  /// False when the resolved account is a card.
  final bool accountIsBank;
}

/// A non-monthly insurance policy (FR-21-07).
class RenewalInput {
  const RenewalInput({
    required this.insurer,
    required this.kindLabel,
    required this.premiumMinor,
    required this.lastPaid,
    required this.nextDue,
  });

  final String insurer;

  /// "Health", "Life", ...
  final String kindLabel;
  final int premiumMinor;
  final DateTime lastPaid;
  final DateTime nextDue;
}

/// An open untracked change on an account (memory 13 `UntrackedGap`).
class GapInput {
  const GapInput({
    required this.key,
    required this.accountId,
    required this.accountLabel,
    required this.deltaMinor,
    required this.card,
    required this.moneyLeft,
    required this.toTimeMs,
  });

  final String key;
  final int accountId;
  final String accountLabel;
  final int deltaMinor;
  final bool card;
  final bool moneyLeft;
  final int toTimeMs;
}

/// One credit card's reminder facts (FR-21-09); the caller derives billed
/// amount and due day from the card position (memory 14).
class CardBillInput {
  const CardBillInput({
    required this.cardId,
    required this.name,
    this.billedMinor,
    this.dueEpochDay,
    this.minDueMinor,
    this.estimated = false,
    this.paid = false,
    this.sent = const {},
    this.snoozedUntilEpochDay,
  });

  final int cardId;

  /// Nickname if not blank, else bank name.
  final String name;
  final int? billedMinor;
  final int? dueEpochDay;
  final int? minDueMinor;
  final bool estimated;
  final bool paid;
  final Set<DueStage> sent;
  final int? snoozedUntilEpochDay;
}

/// An account whose balance a statement or SMS revealed as unexplained
/// (memory 21 `BalanceGap`, FR-21-04).
class BalanceGapInput {
  const BalanceGapInput({
    required this.key,
    required this.label,
    required this.unexplainedMinor,
  });

  final String key;

  /// "{what}": the account label.
  final String label;
  final int unexplainedMinor;
}

/// Setting key of the weekly summary toggle (FR-21-21).
const weeklySummaryKey = SettingKey<bool>('weekly_summary_alert', false);

/// Setting key of the update-available toggle (FR-31-34).
const updateAlertKey = SettingKey<bool>('update_alert', true);

/// Spend of one Monday-to-Sunday week and its biggest category (FR-21-21).
class WeekSpend {
  /// Creates a week.
  const WeekSpend({
    required this.spentMinor,
    this.topCategory,
    this.topCategoryMinor = 0,
  });

  /// Total spent, paise.
  final int spentMinor;

  /// Category with the most spend, null when nothing was spent.
  final Category? topCategory;

  /// Spend in [topCategory], paise.
  final int topCategoryMinor;
}
