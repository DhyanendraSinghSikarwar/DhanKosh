import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/error_handlers.dart';
import 'package:hisaab/shared/log/app_logger.dart';

class _ListSink implements LogSink {
  final lines = <String>[];
  @override
  void append(String line) => lines.add(line);
}

void main() {
  test('global handlers log class names only (FR-35-09)', () {
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
    });
    final sink = _ListSink();
    FlutterError.onError = (_) {};
    installErrorHandlers(SinkAppLogger(sink));
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('Rs 5,000.00 paid to demo@okbank 123456789'),
        stack: StackTrace.fromString('#0 f (package:hisaab/a.dart:3:1)'),
      ),
    );
    PlatformDispatcher.instance.onError!(
      ArgumentError('secret body text'),
      StackTrace.empty,
    );
    logZoneError(
      SinkAppLogger(sink),
      const FormatException('x y z'),
      StackTrace.empty,
    );
    final out = sink.lines.join('\n');
    expect(out, contains('StateError'));
    expect(out, contains('ArgumentError'));
    expect(out, contains('FormatException'));
    expect(out, contains('a.dart:3'));
    for (final bad in ['5,000', 'okbank', '123456789', 'secret', 'x y z']) {
      expect(out, isNot(contains(bad)));
    }
  });
}
