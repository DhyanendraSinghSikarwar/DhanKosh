import 'package:hisaab/core/errors/failure.dart';

/// Success value or [Failure].
sealed class Result<T> {
  const Result();

  /// Runs [body], mapping a thrown [Failure] to [Err]; other errors become
  /// [UnexpectedFailure] carrying only the error type.
  static Future<Result<T>> guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on Failure catch (f) {
      return Err(f);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  /// Collapses the result into a single value.
  R fold<R>(R Function(T value) ok, R Function(Failure failure) err) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };
}

/// Success.
final class Ok<T> extends Result<T> {
  /// Creates an [Ok].
  const Ok(this.value);

  /// The value.
  final T value;
}

/// Failure.
final class Err<T> extends Result<T> {
  /// Creates an [Err].
  const Err(this.failure);

  /// The failure.
  final Failure failure;
}
