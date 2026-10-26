import 'package:hisaab/shared/log/log_models.dart';

/// One-line text form of an entry (FR-35-04):
/// `2026-10-26T10:00:00.000Z | INFO | sms | scan.done | read=10 added=2`.
class LogFormat {
  const LogFormat._();

  /// Formats [e] without a trailing newline.
  static String line(LogEntry e) {
    final f = e.fields.entries.map((x) => '${x.key}=${x.value}').join(' ');
    return [
      e.at.toUtc().toIso8601String(),
      e.level.name.toUpperCase(),
      e.category.name,
      e.code,
      if (f.isNotEmpty) f,
    ].join(' | ');
  }

  /// Parses a line written by [line]; null when it is not one.
  static LogEntry? parse(String line) {
    final p = line.split(' | ');
    if (p.length < 4) return null;
    final at = DateTime.tryParse(p[0]);
    final level = LogLevel.values.where((l) => l.name.toUpperCase() == p[1]);
    final cat = LogCategory.values.where((c) => c.name == p[2]);
    if (at == null || level.isEmpty || cat.isEmpty) return null;
    final fields = <String, String>{};
    if (p.length > 4) {
      for (final kv in p[4].split(' ')) {
        final i = kv.indexOf('=');
        if (i > 0) fields[kv.substring(0, i)] = kv.substring(i + 1);
      }
    }
    return LogEntry(
      at: at,
      level: level.first,
      category: cat.first,
      code: p[3],
      fields: fields,
    );
  }
}
