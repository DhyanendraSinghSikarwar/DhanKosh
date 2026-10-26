import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_format.dart';
import 'package:hisaab/shared/log/log_models.dart';
import 'package:hisaab/shared/log/log_sanitizer.dart';

class _ListSink implements LogSink {
  final lines = <String>[];
  @override
  void append(String line) => lines.add(line);
}

const _body = 'Rs.12,345.67 debited from A/c XX123456789 on 20-10-26 '
    'UPI Ref 412345678901 to demo.shop@okbank. Avl bal Rs 99,000.00';

void main() {
  group('sanitizer (FR-35-05..07)', () {
    test('free text becomes a marker', () {
      expect(LogSanitizer.value(_body), '[long]');
      expect(LogSanitizer.value('hello there'), '[text]');
    });
    test('account numbers and long digit runs are masked', () {
      expect(LogSanitizer.value('123456789012'), '[num]');
      expect(LogSanitizer.value('ac_123456789'), 'ac_[num]');
      expect(LogSanitizer.value('12345'), '12345');
    });
    test('amounts are masked', () {
      expect(LogSanitizer.value('1500.50'), '[num]');
      expect(LogSanitizer.value('Rs.1,500.00'), '[num]');
    });
    test('emails and UPI ids are redacted', () {
      expect(LogSanitizer.value('a.b@example.com'), '[redacted]');
      expect(LogSanitizer.value('demo@okbank'), '[redacted]');
    });
    test('keys are lower-case tokens', () {
      expect(LogSanitizer.key('Scan Done!'), 'scan_done_');
      expect(LogSanitizer.key(''), '_');
    });
    test('safe values pass', () {
      expect(LogSanitizer.value(7), '7');
      expect(LogSanitizer.value('StateError'), 'StateError');
      expect(LogSanitizer.value('scan.dart:42'), 'scan.dart:42');
    });
  });

  group('logger', () {
    test('sample SMS, account, amount, email never reach the sink', () {
      final sink = _ListSink();
      SinkAppLogger(sink).info(
        LogCategory.sms,
        'scan.done',
        fields: {
          'body': _body,
          'acct': 'XX123456789',
          'amount': '12,345.67',
          'mail': 'demo.user@example.com',
          'upi': 'demo.shop@okbank',
          'n': 3,
        },
      );
      final out = sink.lines.join('\n');
      for (final bad in [
        'debited',
        '123456789',
        '12,345',
        '345.67',
        'example.com',
        'okbank',
        '412345678901',
        'demo.shop',
      ]) {
        expect(out, isNot(contains(bad)), reason: bad);
      }
      expect(out, contains('n=3'));
    });

    test('a code carrying text is neutralised', () {
      final sink = _ListSink();
      SinkAppLogger(sink).info(LogCategory.app, 'Paid Rs 500 to Ravi');
      expect(sink.lines.single, isNot(contains('Ravi')));
      expect(sink.lines.single, isNot(contains(' 500 ')));
    });

    test('disabled writes nothing; level filters (FR-35-13)', () {
      final sink = _ListSink();
      var cfg = const LogConfig(enabled: false);
      final log = SinkAppLogger(sink, config: () => cfg)
        ..error(LogCategory.app, 'x');
      expect(sink.lines, isEmpty);
      cfg = const LogConfig();
      log
        ..debug(LogCategory.app, 'dbg')
        ..warn(LogCategory.app, 'w');
      expect(sink.lines, hasLength(1));
      cfg = const LogConfig(level: LogLevel.debug);
      log.debug(LogCategory.app, 'dbg');
      expect(sink.lines, hasLength(2));
    });

    test('errorFields keeps class and file:line only (FR-35-09)', () {
      final f = errorFields(
        StateError('secret 123456789 body'),
        StackTrace.fromString(
          '#0 foo (package:hisaab/a/scan_sms.dart:42:7)\n'
          '#1 bar (package:hisaab/b/x.dart:9:1)',
        ),
      );
      expect(f['type'], 'StateError');
      expect(f['f1'], 'scan_sms.dart:42');
      expect(f['f2'], 'x.dart:9');
      expect('$f', isNot(contains('secret')));
    });
  });

  group('format (FR-35-04)', () {
    test('line and parse round-trip', () {
      final e = LogEntry(
        at: DateTime.utc(2026, 10, 26, 10),
        level: LogLevel.warn,
        category: LogCategory.channel,
        code: 'channel.failed',
        fields: const {'code': 'E1', 'n': '2'},
      );
      final l = LogFormat.line(e);
      expect(
        l,
        '2026-10-26T10:00:00.000Z | WARN | channel | channel.failed | '
        'code=E1 n=2',
      );
      final p = LogFormat.parse(l)!;
      expect(p.code, 'channel.failed');
      expect(p.fields['n'], '2');
      expect(LogFormat.parse('garbage'), isNull);
    });
  });
}
