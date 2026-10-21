/// String key-value store port; implemented over the settings feature's store.
abstract interface class KeyValueStore {
  /// Value for [key], or null.
  Future<String?> getString(String key);

  /// Stores [value] under [key].
  Future<void> setString(String key, String value);
}
