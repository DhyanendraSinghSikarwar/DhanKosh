import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('sqlite3 build hook provides SQLCipher (ADR-0003)', () {
    final dir = Directory.systemTemp.createTempSync('cipher');
    final file = File('${dir.path}/probe.db');
    final db = sqlite3.open(file.path);
    final v = db.select('PRAGMA cipher_version;');
    expect(v, isNotEmpty, reason: 'not SQLCipher');
    db
      ..execute("PRAGMA key = \"x'${'ab' * 32}'\";")
      ..execute('create table t(a); insert into t values (1);');
    db.close();
    // Wrong key must fail; right key must read.
    final bad = sqlite3.open(file.path)
      ..execute("PRAGMA key = \"x'${'cd' * 32}'\";");
    expect(
      () => bad.select('select * from t'),
      throwsA(isA<SqliteException>()),
    );
    bad.close();
    final good = sqlite3.open(file.path)
      ..execute("PRAGMA key = \"x'${'ab' * 32}'\";");
    expect(good.select('select a from t').first['a'], 1);
    good.close();
    dir.deleteSync(recursive: true);
  });
}
