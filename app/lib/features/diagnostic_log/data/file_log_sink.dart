import 'dart:convert';
import 'dart:io';

import 'package:hisaab/features/diagnostic_log/domain/diagnostic_log_store.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_format.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Append-only log file in app-private storage with a size cap and one
/// rotated file (FR-35-10, FR-35-11). Every isolate opens its own instance
/// and appends whole lines, so no shared in-memory state is needed.
class FileLogSink implements LogSink, DiagnosticLogStore {
  /// Log files live in [dir]: `diagnostic.log`, `diagnostic.log.1`.
  FileLogSink(
    this.dir, {
    this.maxBytes = 512 * 1024,
    this.keep = 2,
    this.configTtl = const Duration(seconds: 2),
  });

  /// Directory holding the files.
  final Directory dir;

  /// Cap per file before rotation.
  final int maxBytes;

  /// Files kept including the active one.
  final int keep;

  /// How long a read config is reused.
  final Duration configTtl;

  LogConfig? _cached;
  DateTime? _cachedAt;

  File get _main => File('${dir.path}/diagnostic.log');
  File get _cfg => File('${dir.path}/diagnostic.cfg');
  File _rot(int i) => File('${dir.path}/diagnostic.log.$i');

  @override
  void append(String line) {
    try {
      dir.createSync(recursive: true);
      if (_main.existsSync() && _main.lengthSync() >= maxBytes) _rotate();
      _main.writeAsStringSync(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } on Object {
      // Logging never breaks the app.
    }
  }

  void _rotate() {
    try {
      for (var i = keep - 1; i >= 1; i--) {
        final src = i == 1 ? _main : _rot(i - 1);
        if (!src.existsSync()) continue;
        if (i >= keep - 1 && _rot(i).existsSync()) _rot(i).deleteSync();
        src.renameSync(_rot(i).path);
      }
      if (keep < 2 && _main.existsSync()) _main.deleteSync();
    } on Object {
      // Another isolate rotated first.
    }
  }

  /// Config for [SinkAppLogger]; re-read at most every [configTtl].
  LogConfig currentConfig() {
    final now = DateTime.now();
    final at = _cachedAt;
    if (_cached != null && at != null && now.difference(at) < configTtl) {
      return _cached!;
    }
    var c = const LogConfig();
    try {
      if (_cfg.existsSync()) {
        final m = <String, String>{};
        for (final l in _cfg.readAsLinesSync()) {
          final i = l.indexOf('=');
          if (i > 0) m[l.substring(0, i)] = l.substring(i + 1);
        }
        c = LogConfig(
          enabled: m['enabled'] != '0',
          level: LogLevel.values.firstWhere(
            (v) => v.name == m['level'],
            orElse: () => LogLevel.info,
          ),
        );
      }
    } on Object {
      // Defaults.
    }
    _cached = c;
    _cachedAt = now;
    return c;
  }

  @override
  Future<LogConfig> config() async {
    _cachedAt = null;
    return currentConfig();
  }

  @override
  Future<void> setConfig(LogConfig config) async {
    dir.createSync(recursive: true);
    _cfg.writeAsStringSync(
      'enabled=${config.enabled ? 1 : 0}\nlevel=${config.level.name}\n',
      flush: true,
    );
    _cached = config;
    _cachedAt = DateTime.now();
  }

  List<File> _files() => [
        for (var i = keep - 1; i >= 1; i--) _rot(i),
        _main,
      ].where((f) => f.existsSync()).toList();

  List<String> _allLines() {
    final out = <String>[];
    for (final f in _files()) {
      try {
        out.addAll(
          const LineSplitter().convert(
            utf8.decode(f.readAsBytesSync(), allowMalformed: true),
          ),
        );
      } on Object {
        // Skip an unreadable file.
      }
    }
    return out;
  }

  @override
  Future<List<String>> lines({int limit = 200}) async {
    final all = _allLines();
    return all.length <= limit ? all : all.sublist(all.length - limit);
  }

  @override
  Future<List<LogEntry>> recent({int limit = 500}) async => [
        for (final l in await lines(limit: limit))
          if (LogFormat.parse(l) case final e?) e,
      ];

  @override
  Future<LogStats> stats() async {
    var bytes = 0;
    for (final f in _files()) {
      try {
        bytes += f.lengthSync();
      } on Object {
        // Skip.
      }
    }
    return LogStats(bytes: bytes, entries: _allLines().length);
  }

  @override
  Future<void> clear() async {
    for (final f in _files()) {
      try {
        f.deleteSync();
      } on Object {
        // Skip.
      }
    }
  }

  @override
  Future<String> exportText() async => '${_allLines().join('\n')}\n';
}
