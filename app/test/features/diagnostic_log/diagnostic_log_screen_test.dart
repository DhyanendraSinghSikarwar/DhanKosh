import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/log_providers.dart';
import 'package:hisaab/features/diagnostic_log/domain/diagnostic_log_store.dart';
import 'package:hisaab/features/diagnostic_log/presentation/diagnostic_log_screen.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_format.dart';
import 'package:hisaab/shared/log/log_models.dart';

class _FakeStore implements DiagnosticLogStore {
  _FakeStore(this.entries);
  List<LogEntry> entries;
  LogConfig cfg = const LogConfig();
  @override
  Future<LogConfig> config() async => cfg;
  @override
  Future<void> setConfig(LogConfig config) async => cfg = config;
  @override
  Future<List<LogEntry>> recent({int limit = 500}) async => entries;
  @override
  Future<List<String>> lines({int limit = 200}) async =>
      entries.map(LogFormat.line).toList();
  @override
  Future<LogStats> stats() async =>
      LogStats(bytes: 2048, entries: entries.length);
  @override
  Future<void> clear() async => entries = [];
  @override
  Future<String> exportText() async => 'EXPORTED';
}

class _FakeGateway implements LogExportGateway {
  String? name;
  List<int>? bytes;
  @override
  Future<String?> save(String fileName, List<int> bytes) async {
    name = fileName;
    this.bytes = bytes;
    return fileName;
  }
}

LogEntry _e(LogCategory c, String code) => LogEntry(
      at: DateTime.utc(2026, 10, 26),
      level: LogLevel.info,
      category: c,
      code: code,
    );

Future<void> _pump(
  WidgetTester t,
  _FakeStore store,
  _FakeGateway gw,
) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        diagnosticLogStoreProvider.overrideWith((ref) async => store),
        logExportGatewayProvider.overrideWithValue(gw),
      ],
      child: const MaterialApp(home: DiagnosticLogScreen()),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('empty state and privacy note (FR-35-14, FR-35-15)', (t) async {
    await _pump(t, _FakeStore([]), _FakeGateway());
    expect(find.byKey(const Key('log-empty')), findsOneWidget);
    expect(
      find.text(
        'Logs stay on this phone. They never include messages, amounts or '
        'names.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('populated, filter, toggle (FR-35-14, FR-35-17)', (t) async {
    final store = _FakeStore([
      _e(LogCategory.sms, 'scan.done'),
      _e(LogCategory.db, 'db.open'),
    ]);
    await _pump(t, store, _FakeGateway());
    expect(find.textContaining('scan.done'), findsOneWidget);
    expect(find.textContaining('db.open'), findsOneWidget);
    await t.tap(find.byKey(const Key('log-chip-db')));
    await t.pumpAndSettle();
    expect(find.textContaining('scan.done'), findsNothing);
    await t.tap(find.byKey(const Key('log-toggle')));
    await t.pumpAndSettle();
    expect(store.cfg.enabled, isFalse);
  });

  testWidgets('export and clear with confirm (FR-35-16, FR-35-18)', (t) async {
    final store = _FakeStore([_e(LogCategory.app, 'app.start')]);
    final gw = _FakeGateway();
    await _pump(t, store, gw);
    await t.tap(find.byKey(const Key('log-export')));
    await t.pumpAndSettle();
    expect(gw.name, startsWith('dhankosh-log-'));
    expect(gw.name, endsWith('.txt'));
    expect(String.fromCharCodes(gw.bytes!), 'EXPORTED');
    await t.tap(find.byKey(const Key('log-clear')));
    await t.pumpAndSettle();
    expect(store.entries, hasLength(1));
    await t.tap(find.byKey(const Key('log-clear-confirm')));
    await t.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.byKey(const Key('log-empty')), findsOneWidget);
  });
}
