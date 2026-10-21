import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/db_key_store.dart';

void main() {
  test('generateDbKeyHex gives 64 lowercase hex chars', () {
    final key = generateDbKeyHex(Random(1));
    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
  });
  test('different seeds give different keys', () {
    expect(generateDbKeyHex(Random(1)), isNot(generateDbKeyHex(Random(2))));
  });
}
