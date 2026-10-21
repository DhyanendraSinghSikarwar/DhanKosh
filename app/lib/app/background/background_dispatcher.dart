import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hisaab/app/background/sms_background_tasks.dart';
import 'package:hisaab/core/platform_channels/background_channel.dart';
import 'package:hisaab/core/platform_channels/background_tasks.dart';

/// Runs one background task; true when finished (including "nothing to do"),
/// false to ask native for a retry.
typedef BackgroundHandler = Future<bool> Function();

/// Task name to handler. Features add their handler here (one call each).
class BackgroundRegistry {
  /// Creates an empty registry.
  BackgroundRegistry();

  /// The registry the app ships with.
  factory BackgroundRegistry.standard() => BackgroundRegistry()
    ..register(BackgroundTasks.smsDrain, smsDrainTask)
    ..register(BackgroundTasks.smsNightly, smsNightlyTask);

  final Map<String, BackgroundHandler> _handlers = {};

  /// Adds or replaces the handler for [task].
  void register(String task, BackgroundHandler handler) =>
      _handlers[task] = handler;

  /// Whether [task] has a handler.
  bool has(String task) => _handlers.containsKey(task);

  /// Runs [task]. Unknown task, error and timeout all return false; nothing
  /// is thrown and no message text is ever logged.
  Future<bool> run(
    String task, {
    Duration timeout = const Duration(minutes: 8),
  }) async {
    final handler = _handlers[task];
    if (handler == null) return false;
    try {
      return await handler().timeout(timeout);
    } on Object {
      return false;
    }
  }
}

/// Reads the task from native, runs it, reports back and lets native stop
/// the engine.
Future<void> runBackgroundTask({
  BackgroundChannel channel = const BackgroundChannel(),
  BackgroundRegistry? registry,
}) async {
  var ok = false;
  try {
    final task = await channel.getTask();
    if (task != null) {
      ok = await (registry ?? BackgroundRegistry.standard()).run(task);
    }
  } on Object {
    ok = false;
  }
  try {
    await channel.done(ok: ok);
  } on Object {
    // Native already gone.
  }
}

/// Entry point of the headless engine started by native `HeadlessRunner`
/// (SMS received with the app closed, nightly scan). Referenced by name from
/// Kotlin: keep the library path and function name in sync.
@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(runBackgroundTask());
}
