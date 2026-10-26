import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Size and entry count of the on-device log (FR-35-14).
class LogStats {
  /// Creates stats.
  const LogStats({this.bytes = 0, this.entries = 0});

  /// Bytes on disk, all rotated files.
  final int bytes;

  /// Lines on disk.
  final int entries;
}

/// Reads, clears and exports the local diagnostic log (F-35). Nothing leaves
/// the phone except by an explicit user action.
abstract interface class DiagnosticLogStore {
  /// Current switches.
  Future<LogConfig> config();

  /// Persists the switches (shared with the background isolate).
  Future<void> setConfig(LogConfig config);

  /// Newest-last entries, at most [limit].
  Future<List<LogEntry>> recent({int limit = 500});

  /// Raw lines, newest last, at most [limit].
  Future<List<String>> lines({int limit = 200});

  /// Size and count.
  Future<LogStats> stats();

  /// Deletes all log files.
  Future<void> clear();

  /// Whole log as text (rotated file first).
  Future<String> exportText();
}

/// Writes the exported log through the system picker (FR-35-18).
abstract interface class LogExportGateway {
  /// Saves [bytes] as [fileName]; returns the saved name, or null on cancel.
  Future<String?> save(String fileName, List<int> bytes);
}
