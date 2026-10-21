/// Typed error raised across layers; never carries financial data.
sealed class Failure implements Exception {
  const Failure(this.message);

  /// Short, user-safe description.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Local database or file storage problem.
final class StorageFailure extends Failure {
  /// Creates a [StorageFailure].
  const StorageFailure(super.message);
}

/// A platform-channel call failed or the native side is missing.
final class ChannelFailure extends Failure {
  /// Creates a [ChannelFailure] with the native error [code].
  const ChannelFailure(this.code, super.message);

  /// Native error code, or `unavailable` when no handler exists.
  final String code;
}

/// A required Android permission or access is not granted.
final class PermissionFailure extends Failure {
  /// Creates a [PermissionFailure].
  const PermissionFailure(super.message);
}

/// Anything else; wraps the original error text only.
final class UnexpectedFailure extends Failure {
  /// Creates an [UnexpectedFailure].
  const UnexpectedFailure(super.message);
}
