/// A password the user asked to remember for locked statements (FR-12).
class SavedPassword {
  /// Creates a saved password.
  const SavedPassword({required this.label, required this.secret});

  /// Shown in the UI (never the secret).
  final String label;

  /// The password; only ever held in memory or the sealed store.
  final String secret;
}

/// Sealed list of saved statement passwords (FR-05-10).
abstract interface class SavedPasswordRepository {
  /// All saved passwords in save order.
  Future<List<SavedPassword>> list();

  /// Saves (or replaces by label) a password.
  Future<void> add(SavedPassword p);

  /// Removes by label.
  Future<void> remove(String label);
}
