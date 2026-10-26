import 'package:hisaab/shared/log/log_format.dart';
import 'package:hisaab/shared/log/log_models.dart';
import 'package:hisaab/shared/log/log_sanitizer.dart';

/// Diagnostic log port (F-35). Never pass message text, amounts, names,
/// account numbers or ids: only counts, durations, enum names, error classes.
/// Implementations never throw.
abstract interface class AppLogger {
  /// Logs verbose detail.
  void debug(LogCategory category, String code, {Map<String, Object?>? fields});

  /// Logs a normal event.
  void info(LogCategory category, String code, {Map<String, Object?>? fields});

  /// Logs a recoverable problem.
  void warn(LogCategory category, String code, {Map<String, Object?>? fields});

  /// Logs a failure.
  void error(LogCategory category, String code, {Map<String, Object?>? fields});
}

/// Logger that drops everything; the default everywhere (FR-35-12).
class NoopAppLogger implements AppLogger {
  /// Creates the no-op logger.
  const NoopAppLogger();

  @override
  void debug(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) {}

  @override
  void info(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) {}

  @override
  void warn(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) {}

  @override
  void error(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) {}
}

/// Process-wide logger for seams without constructor injection. Each isolate
/// has its own copy; `main` and the headless entry install the file logger.
class AppLog {
  const AppLog._();

  /// The installed logger; no-op until [install].
  static AppLogger instance = const NoopAppLogger();

  /// Installs [logger] for this isolate.
  // ignore: use_setters_to_change_properties
  static void install(AppLogger logger) => instance = logger;
}

/// Where formatted lines go (a file in the app; a list in tests).
abstract interface class LogSink {
  /// Appends one line; must not throw.
  void append(String line);
}

/// Current switches, read on every call so the toggle works across isolates.
class LogConfig {
  /// Creates a config.
  const LogConfig({this.enabled = true, this.level = LogLevel.info});

  /// Whether anything is written.
  final bool enabled;

  /// Lowest level written.
  final LogLevel level;
}

/// [AppLogger] that sanitises, filters by [LogConfig] and writes to a sink.
class SinkAppLogger implements AppLogger {
  /// Creates the logger.
  SinkAppLogger(
    this._sink, {
    LogConfig Function()? config,
    DateTime Function()? now,
  })  : _config = config ?? (() => const LogConfig()),
        _now = now ?? DateTime.now;

  final LogSink _sink;
  final LogConfig Function() _config;
  final DateTime Function() _now;

  void _log(
    LogLevel level,
    LogCategory category,
    String code,
    Map<String, Object?>? fields,
  ) {
    try {
      final c = _config();
      if (!c.enabled || level.index < c.level.index) return;
      _sink.append(
        LogFormat.line(
          LogEntry(
            at: _now().toUtc(),
            level: level,
            category: category,
            code: LogSanitizer.key(code),
            fields: LogSanitizer.fields(fields),
          ),
        ),
      );
    } on Object {
      // Logging never breaks the app.
    }
  }

  @override
  void debug(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) =>
      _log(LogLevel.debug, category, code, fields);

  @override
  void info(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) =>
      _log(LogLevel.info, category, code, fields);

  @override
  void warn(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) =>
      _log(LogLevel.warn, category, code, fields);

  @override
  void error(
    LogCategory category,
    String code, {
    Map<String, Object?>? fields,
  }) =>
      _log(LogLevel.error, category, code, fields);
}

/// Error class and stack frames (file:line only) for a caught error; the
/// message text is never read (FR-35-09).
Map<String, Object?> errorFields(Object error, [StackTrace? stack]) {
  final frames = <String>[];
  final re = RegExp(r'([A-Za-z0-9_]+\.dart):(\d+)');
  for (final m in re.allMatches('${stack ?? ''}')) {
    frames.add('${m.group(1)}:${m.group(2)}');
    if (frames.length == 4) break;
  }
  final type = error.runtimeType.toString().split('<').first;
  return {
    'type': type,
    for (var i = 0; i < frames.length; i++) 'f${i + 1}': frames[i],
  };
}
