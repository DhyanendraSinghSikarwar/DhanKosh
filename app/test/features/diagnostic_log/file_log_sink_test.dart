import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/diagnostic_log/data/file_log_sink.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('dlog'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('rotation keeps the cap and two files (FR-35-10, FR-35-11)', () async {
    final sink = FileLogSink(dir, maxBytes: 200);
    for (var i = 0; i < 40; i++) {
      sink.append('line $i xxxxxxxxxxxxxxxxxxxx');
    }
    final names = dir.listSync().map((e) => e.path.split('/').last).toSet();
    expect(names, containsAll(['diagnostic.log', 'diagnostic.log.1']));
    expect(names.where((n) => n.startsWith('diagnostic.log')), hasLength(2));
    final st = await sink.stats();
    expect(st.bytes, lessThan(200 * 2 + 60));
    final lines = await sink.lines(limit: 1000);
    expect(lines.last, startsWith('line 39'));
  });

  test('two writers append without corrupting lines (FR-35-10)', () async {
    final a = FileLogSink(dir);
    final b = FileLogSink(dir);
    await Future.wait([
      for (var i = 0; i < 50; i++) ...[
        Future(() => a.append('A$i | ${'a' * 30}')),
        Future(() => b.append('B$i | ${'b' * 30}')),
      ],
    ]);
    final lines = await a.lines(limit: 1000);
    expect(lines, hasLength(100));
    expect(
      lines.every((l) => RegExp(r'^[AB]\d+ \| (a{30}|b{30})$').hasMatch(l)),
      isTrue,
    );
  });

  test('config persists across instances; off writes nothing (FR-35-13)',
      () async {
    final a = FileLogSink(dir);
    expect((await a.config()).enabled, isTrue);
    await a.setConfig(const LogConfig(enabled: false, level: LogLevel.debug));
    final b = FileLogSink(dir);
    final c = await b.config();
    expect(c.enabled, isFalse);
    expect(c.level, LogLevel.debug);
    SinkAppLogger(b, config: b.currentConfig).info(LogCategory.app, 'x');
    expect((await b.stats()).entries, 0);
  });

  test('clear and export (FR-35-16, FR-35-18)', () async {
    final s = FileLogSink(dir);
    SinkAppLogger(s).info(LogCategory.sms, 'scan.done', fields: {'n': 1});
    expect(await s.exportText(), contains('scan.done'));
    expect((await s.recent()).single.code, 'scan.done');
    await s.clear();
    expect((await s.stats()).entries, 0);
  });
}
