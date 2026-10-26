import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/features/diagnostic_log/data/log_export_gateway.dart';
import 'package:hisaab/features/diagnostic_log/data/log_location.dart';
import 'package:hisaab/features/diagnostic_log/domain/diagnostic_log_store.dart';
import 'package:hisaab/shared/log/app_logger.dart';

/// File-backed log store (F-35); overridden in tests.
final diagnosticLogStoreProvider = FutureProvider<DiagnosticLogStore>(
  (ref) async => await openDiagnosticSink(),
);

/// Save dialog for the exported log; overridden in tests.
final logExportGatewayProvider = Provider<LogExportGateway>(
  (ref) => FilePickerLogExportGateway(
    lockSkipper: ref.watch(lockSkipperProvider),
  ),
);

/// Logger for code that reads it from a provider (FR-35-12).
final appLoggerProvider = Provider<AppLogger>((ref) => AppLog.instance);
