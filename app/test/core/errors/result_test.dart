import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/core/errors/result.dart';

void main() {
  test('guard returns Ok on success', () async {
    final r = await Result.guard(() async => 7);
    expect(r.fold((v) => v, (_) => -1), 7);
  });
  test('guard keeps a thrown Failure', () async {
    final r = await Result.guard<int>(
      () async => throw const StorageFailure('disk'),
    );
    expect(r.fold((_) => null, (f) => f), isA<StorageFailure>());
  });
  test('guard wraps other errors without leaking their message', () async {
    final r = await Result.guard<int>(() async => throw StateError('amt 500'));
    final f = r.fold((_) => null, (f) => f)!;
    expect(f, isA<UnexpectedFailure>());
    expect(f.message, isNot(contains('500')));
  });
}
