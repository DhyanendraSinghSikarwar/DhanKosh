import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// [CardPaidStore] over the settings table (`card_due_paid`).
class CardPaidStoreImpl implements CardPaidStore {
  /// Creates the store.
  const CardPaidStoreImpl(this._settings);

  final SettingsRepository _settings;

  static const _key = SettingKey<Set<String>>('card_due_paid', <String>{});

  @override
  Future<void> markPaid(int cardId, int dueEpochDay) async {
    final s = await _settings.read(_key);
    await _settings.write(_key, {...s, CardPaidStore.key(cardId, dueEpochDay)});
  }

  @override
  Future<void> undoPaid(int cardId, int dueEpochDay) async {
    final s = await _settings.read(_key);
    await _settings.write(
      _key,
      {...s}..remove(CardPaidStore.key(cardId, dueEpochDay)),
    );
  }

  @override
  Stream<Set<String>> watchPaid() => _settings.watch(_key);
}
