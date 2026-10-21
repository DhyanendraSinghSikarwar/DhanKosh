/// Sent-alert dedupe keys (FR-21-14). Newest [cap] kept.
abstract interface class AlertedKeyStore {
  /// Entries kept.
  static const cap = 300;

  /// True when [key] was already sent.
  Future<bool> has(String key);

  /// Every stored key.
  Future<Set<String>> all();

  /// Records [key] at [sentAtMs] and prunes to the newest [cap].
  Future<void> add(String key, int sentAtMs);

  /// Removes everything (data reset).
  Future<void> clear();
}
