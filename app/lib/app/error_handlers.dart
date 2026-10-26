import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Routes uncaught errors to the diagnostic log as class name and stack
/// frames (file:line) only; the message text is never read (FR-35-09).
void installErrorHandlers(AppLogger log) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    log.error(
      LogCategory.app,
      'error.flutter',
      fields: errorFields(details.exception, details.stack),
    );
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error(
      LogCategory.app,
      'error.platform',
      fields: errorFields(error, stack),
    );
    return false;
  };
}

/// Logs an error caught by `runZonedGuarded`.
void logZoneError(AppLogger log, Object error, StackTrace stack) => log.error(
      LogCategory.app,
      'error.zone',
      fields: errorFields(error, stack),
    );

/// Runs [body] in a guarded zone that logs uncaught errors.
void runGuarded(AppLogger Function() log, void Function() body) {
  runZonedGuarded(body, (e, s) => logZoneError(log(), e, s));
}
