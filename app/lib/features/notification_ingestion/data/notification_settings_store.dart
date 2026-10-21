import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

/// [NotificationSettingsRepository] over a [KeyValueStore]; key
/// `app_notifications`, default false (FR-04-02).
class NotificationSettingsStore implements NotificationSettingsRepository {
  /// Creates the store.
  const NotificationSettingsStore(this._kv);

  final KeyValueStore _kv;

  static const _key = 'app_notifications';

  @override
  Future<bool> isEnabled() async => (await _kv.getString(_key)) == 'true';

  @override
  Future<void> setEnabled({required bool enabled}) =>
      _kv.setString(_key, '$enabled');
}
