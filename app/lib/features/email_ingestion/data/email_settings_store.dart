import 'dart:convert';

import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

/// [EmailSettingsRepository] over the settings table. The password is not
/// here, see `SecureEmailCredentialStore`.
class EmailSettingsStore implements EmailSettingsRepository {
  /// Creates the store.
  const EmailSettingsStore(this._kv);

  final KeyValueStore _kv;

  static const _address = 'email_address';
  static const _provider = 'email_provider';
  static const _host = 'email_imap_host';
  static const _port = 'email_imap_port';
  static const _lastSync = 'email_last_sync';
  static const _lastReport = 'email_last_report';
  static const _reauth = 'email_needs_reauth';
  static const _senders = 'email_custom_senders';

  /// Shared look-back key (F-26 `history_days`).
  static const _history = 'history_days';

  @override
  Future<EmailAccount?> account() async {
    final address = await _kv.getString(_address);
    if (address == null) return null;
    final provider =
        EmailProvider.values.asNameMap()[await _kv.getString(_provider)] ??
            EmailProvider.detect(address);
    return EmailAccount(
      address: address,
      provider: provider,
      imapHost: await _kv.getString(_host) ?? provider.imapHost,
      imapPort: int.tryParse(await _kv.getString(_port) ?? '') ?? 993,
    );
  }

  @override
  Future<void> saveAccount(EmailAccount a) async {
    await _kv.setString(_address, a.address);
    await _kv.setString(_provider, a.provider.name);
    await _kv.setString(_host, a.imapHost);
    await _kv.setString(_port, '${a.imapPort}');
    await _kv.setString(_reauth, 'false');
  }

  @override
  Future<void> clearAccount() async {
    for (final k in [
      _address,
      _provider,
      _host,
      _port,
      _lastSync,
      _lastReport,
      _reauth,
    ]) {
      await _kv.setString(k, '');
    }
  }

  @override
  Future<int> lastSyncAt() async =>
      int.tryParse(await _kv.getString(_lastSync) ?? '') ?? 0;

  @override
  Future<void> saveSync({required int at, required String report}) async {
    await _kv.setString(_lastSync, '$at');
    await _kv.setString(_lastReport, report);
  }

  @override
  Future<void> saveReport(String report) => _kv.setString(_lastReport, report);

  @override
  Future<void> forgetPosition() => _kv.setString(_lastSync, '');

  @override
  Future<String?> lastReport() => _kv.getString(_lastReport);

  @override
  Future<int> lookbackDays() async =>
      int.tryParse(await _kv.getString(_history) ?? '') ?? 90;

  @override
  Future<bool> needsReauth() async => await _kv.getString(_reauth) == 'true';

  @override
  Future<void> setNeedsReauth({required bool value}) =>
      _kv.setString(_reauth, '$value');

  @override
  Future<Set<String>> customSenders() async {
    final raw = await _kv.getString(_senders);
    if (raw == null) return {};
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
}
