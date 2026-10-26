import 'dart:io';

import 'package:hisaab/features/diagnostic_log/data/file_log_sink.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the log in app-private storage (`<support dir>/logs`); callable from
/// any isolate (FR-35-10).
Future<FileLogSink> openDiagnosticSink() async {
  final base = await getApplicationSupportDirectory();
  return FileLogSink(Directory('${base.path}/logs'));
}

/// Opens the sink and installs its logger as [AppLog.instance] for this
/// isolate. Falls back to the no-op logger when storage is unavailable.
Future<AppLogger> installDiagnosticLogger() async {
  try {
    final sink = await openDiagnosticSink();
    final logger = SinkAppLogger(sink, config: sink.currentConfig);
    AppLog.install(logger);
    return logger;
  } on Object {
    return AppLog.instance;
  }
}
