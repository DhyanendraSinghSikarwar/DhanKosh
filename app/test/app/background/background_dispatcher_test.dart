import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/background/background_dispatcher.dart';
import 'package:hisaab/core/platform_channels/background_tasks.dart';

// FR-02-01, FR-02-14: task registry and headless runner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundRegistry', () {
    test('runs the registered handler', () async {
      final r = BackgroundRegistry()..register('t', () async => true);
      expect(r.has('t'), isTrue);
      expect(await r.run('t'), isTrue);
    });

    test('unknown task, error and timeout are false, never thrown', () async {
      final r = BackgroundRegistry()
        ..register('boom', () async => throw StateError('x'))
        ..register('slow', () => Completer<bool>().future)
        ..register('later', () async => false);
      expect(await r.run('nope'), isFalse);
      expect(await r.run('boom'), isFalse);
      expect(
        await r.run('slow', timeout: const Duration(milliseconds: 20)),
        isFalse,
      );
      expect(await r.run('later'), isFalse);
    });

    test('standard registry knows the SMS tasks', () {
      final r = BackgroundRegistry.standard();
      expect(r.has(BackgroundTasks.smsDrain), isTrue);
      expect(r.has(BackgroundTasks.smsNightly), isTrue);
    });
  });

  group('runBackgroundTask', () {
    const channel = MethodChannel('com.hisaab/background');
    final calls = <MethodCall>[];

    void mock(String? task) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'getTask' ? task : null;
      });
    }

    setUp(calls.clear);
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('runs the named task and reports ok', () async {
      mock('t');
      var ran = false;
      await runBackgroundTask(
        registry: BackgroundRegistry()
          ..register('t', () async {
            ran = true;
            return true;
          }),
      );
      expect(ran, isTrue);
      expect(calls.last.method, 'done');
      expect((calls.last.arguments as Map)['ok'], isTrue);
    });

    test('unknown task reports not ok', () async {
      mock('other');
      await runBackgroundTask(registry: BackgroundRegistry());
      expect((calls.last.arguments as Map)['ok'], isFalse);
    });
  });
}
