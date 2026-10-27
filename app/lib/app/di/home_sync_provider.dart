import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';

/// State of the Home sync button and progress pill (FR-17-17, FR-17-18).
class HomeSyncState {
  /// Creates a state.
  const HomeSyncState({
    this.running = false,
    this.scanned = 0,
    this.found = 0,
    this.done,
  });

  /// A sync is in flight.
  final bool running;

  /// Bank messages read so far.
  final int scanned;

  /// Messages parsed so far.
  final int found;

  /// Result line, shown for 3 seconds after a sync.
  final String? done;
}

/// Runs "sync everything": 14-day SMS re-read, email sync, alert checks.
/// Ignored while a sync is already active (FR-17-17).
class HomeSyncNotifier extends Notifier<HomeSyncState> {
  @override
  HomeSyncState build() => const HomeSyncState();

  /// Starts a sync; never throws.
  Future<void> sync() async {
    if (state.running) return;
    state = const HomeSyncState(running: true);
    var read = 0;
    try {
      final scan = ref.read(scanSmsFactoryProvider)(
        (p) => state = HomeSyncState(
          running: true,
          scanned: p.scanned,
          found: p.found,
        ),
      );
      final r = await scan(const SmsScanRequest.recent(14));
      read = r.bankMessages;
    } on Object {
      // Native side missing (tests, desktop).
    }
    try {
      await ref.read(emailSyncRunnerProvider).run();
    } on Object {
      // Not connected.
    }
    try {
      await ref.read(alertsEngineProvider).run();
    } on Object {
      // Alerts are best effort.
    }
    state = HomeSyncState(done: '$read read');
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!state.running) state = const HomeSyncState();
      }),
    );
  }
}

/// Home sync state and action (FR-17-17, FR-17-18).
final homeSyncProvider =
    NotifierProvider<HomeSyncNotifier, HomeSyncState>(HomeSyncNotifier.new);
