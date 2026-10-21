/// A typed settings key with a default (FR-26-12). Supported [T]: bool, int,
/// String, `Set<String>`.
class SettingKey<T> {
  const SettingKey(this.name, this.defaultValue, {this.normalize});

  final String name;
  final T defaultValue;

  /// Applied on write to `(stored, incoming)`: monotonic or capped values.
  final T Function(T stored, T incoming)? normalize;
}

/// Keys read by other features (memory 26 section 2.5), subset for Phase 1.
abstract final class SettingKeys {
  static const smsEnabled = SettingKey<bool>('sms_enabled', true);

  /// Only increases on write (FR-26-14); reset with `remove`.
  static final smsCursor = SettingKey<int>(
    'sms_cursor',
    0,
    normalize: (stored, incoming) => incoming > stored ? incoming : stored,
  );
  static const lastSmsScan = SettingKey<int>('last_sms_scan', 0);
  static const lastSmsResult = SettingKey<String>('last_sms_result', '');
  static const smsPromptDismissed = SettingKey<bool>(
    'sms_prompt_dismissed',
    false,
  );
  static const appNotifications = SettingKey<bool>('app_notifications', false);
  static const notificationsAsked = SettingKey<bool>(
    'notifications_asked',
    false,
  );
  static const historyDays = SettingKey<int>('history_days', 90);
  static const hideAmounts = SettingKey<bool>('hide_amounts', true);
  static const appLock = SettingKey<bool>('app_lock', false);
  static const transactionNotifications = SettingKey<bool>(
    'transaction_notifications',
    true,
  );
  static const cardDueReminders = SettingKey<bool>('card_due_reminders', true);
  static const checkUpdates = SettingKey<bool>('check_updates', true);

  /// Shows the Developer section (sample data, clear data). ON in this early
  /// build (FR-26-30).
  static const developerTools = SettingKey<bool>('developer_tools', true);
  static const budgetAlertPercent = SettingKey<int>('budget_alert_percent', 90);

  /// Capped to the most recent 300 entries (FR-26-13); newest last.
  static const alertedKeysCap = 300;
}
