import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/app.dart';
import 'package:hisaab/app/error_handlers.dart';
import 'package:hisaab/features/diagnostic_log/data/log_location.dart';
import 'package:hisaab/shared/log/app_logger.dart';

void main() {
  runGuarded(() => AppLog.instance, () async {
    WidgetsFlutterBinding.ensureInitialized();
    installErrorHandlers(await installDiagnosticLogger());
    runApp(const ProviderScope(child: HisaabApp()));
  });
}
