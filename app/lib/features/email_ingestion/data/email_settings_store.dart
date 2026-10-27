import 'dart:convert';

import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

/// [EmailSettingsRepository] over the settings table: one JSON list of
/// mailboxes with their cursor and report (FR-03-06). Passwords are not
/// here, see `SecureEmailCredentialStore`.
class EmailSettingsStore implements EmailSettingsRepository {
  /// Creates the store.
  const EmailSettingsStore(this._kv);

  final KeyValueStore _kv;

  static const _list = 'email_accounts';
  static const _senders = 'email_custom_senders';
  static const _removed = 'email_removed_senders';

  /// Shared look-back key (F-26 `history_days`).
  static const _history = 'history_days';

  Future<List<Map<String, Object?>>> _read() async {
    final raw = await _kv.getString(_list);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final m in jsonDecode(raw) as List)
          Map<String, Object?>.from(m as Map),
      ];
    } on Object {
      return [];
    }
  }

  Future<void> _write(List<Map<String, Object?>> rows) =>
      _kv.setString(_list, rows.isEmpty ? '' : jsonEncode(rows));

  static EmailAccount _account(Map<String, Object?> m) {
    final address = m['address']! as String;
    final provider = EmailProvider.values.asNameMap()[m['provider']] ??
        EmailProvider.detect(address);
    return EmailAccount(
      address: address,
      provider: provider,
      imapHost: (m['host'] as String?) ?? provider.imapHost,
      imapPort: (m['port'] as int?) ?? 993,
      enabled: (m['enabled'] as bool?) ?? true,
    );
  }

  Future<void> _update(
    String address,
    void Function(Map<String, Object?> row) change,
  ) async {
    final a = address.trim().toLowerCase();
    final rows = await _read();
    for (final r in rows) {
      if (r['address'] == a) change(r);
    }
    await _write(rows);
  }

  Future<Map<String, Object?>?> _row(String address) async {
    final a = address.trim().toLowerCase();
    for (final r in await _read()) {
      if (r['address'] == a) return r;
    }
    return null;
  }

  @override
  Future<List<EmailAccount>> accounts() async =>
      [for (final r in await _read()) _account(r)];

  @override
  Future<EmailAccount?> account() async {
    final all = await accounts();
    return all.isEmpty ? null : all.first;
  }

  @override
  Future<void> saveAccount(EmailAccount a) async {
    final rows = await _read()
      ..removeWhere((r) => r['address'] == a.address)
      ..add({
        'address': a.address,
        'provider': a.provider.name,
        'host': a.imapHost,
        'port': a.imapPort,
        'enabled': a.enabled,
      });
    await _write(rows);
  }

  @override
  Future<void> setEnabled(String address, {required bool enabled}) =>
      _update(address, (r) => r['enabled'] = enabled);

  @override
  Future<void> removeAccount(String address) async {
    final a = address.trim().toLowerCase();
    await _write(
      await _read()
        ..removeWhere((r) => r['address'] == a),
    );
  }

  @override
  Future<int> lastSyncAt(String address) async =>
      (await _row(address))?['lastSync'] as int? ?? 0;

  @override
  Future<void> saveSync(
    String address, {
    required int at,
    required String report,
  }) =>
      _update(address, (r) {
        r['lastSync'] = at;
        r['report'] = report;
      });

  @override
  Future<void> saveReport(String address, String report) =>
      _update(address, (r) => r['report'] = report);

  @override
  Future<void> forgetPosition() async {
    final rows = await _read();
    for (final r in rows) {
      r['lastSync'] = 0;
    }
    await _write(rows);
  }

  @override
  Future<String?> lastReport(String address) async =>
      (await _row(address))?['report'] as String?;

  @override
  Future<int> lookbackDays() async {
    final d = int.tryParse(await _kv.getString(_history) ?? '') ?? 90;
    return d.clamp(7, 365);
  }

  @override
  Future<bool> needsReauth(String address) async =>
      (await _row(address))?['reauth'] as bool? ?? false;

  @override
  Future<void> setNeedsReauth(String address, {required bool value}) =>
      _update(address, (r) => r['reauth'] = value);

  @override
  Future<Set<String>> customSenders() async {
    final raw = await _kv.getString(_senders);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } on Object {
      return {};
    }
  }

  @override
  Future<void> saveCustomSenders(Set<String> senders) async {
    await _kv.setString(
      _senders,
      senders.isEmpty ? '' : jsonEncode(senders.toList()),
    );
    await forgetPosition();
  }

  @override
  Future<Set<String>> removedDefaultSenders() async {
    final raw = await _kv.getString(_removed);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } on Object {
      return {};
    }
  }

  @override
  Future<void> saveRemovedDefaultSenders(Set<String> senders) async {
    await _kv.setString(
      _removed,
      senders.isEmpty ? '' : jsonEncode(senders.toList()),
    );
    await forgetPosition();
  }
}
