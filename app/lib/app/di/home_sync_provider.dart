import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';

/// Stage of a Home sync (FR-17-42).
enum HomeSyncStage { idle, sms, email, matching, done }

/// State of the Home sync button and refresh sheet (FR-17-17, FR-17-18,
/// FR-17-42).
class HomeSyncState {
  /// Creates a state.
  const HomeSyncState({
    this.running = false,
    this.scanned = 0,
    this.found = 0,
    this.done,
    this.stage = HomeSyncStage.idle,
    this.newCount = 0,
    this.reviewCount = 0,
  });

  /// A sync is in flight.
  final bool running;

  /// Bank messages read so far.
  final int scanned;

  /// Messages parsed so far.
  final int found;

  /// Short result of the last sync (messages read).
  final String? done;

  /// Current step; [HomeSyncStage.done] stays until the next sync.
  final HomeSyncStage stage;

  /// Transactions added by the last sync (SMS plus email).
  final int newCount;

  /// Transactions the last sync flagged for review.
  final int reviewCount;

  /// 0..1: SMS 0-55%, email 55-85%, matching 85-100%. SMS has no known total,
  /// so its share grows with the messages read.
  double get progress => switch (stage) {
        HomeSyncStage.idle => 0,
        HomeSyncStage.sms => 0.55 * smsFraction,
        HomeSyncStage.email => 0.55,
        HomeSyncStage.matching => 0.85,
        HomeSyncStage.done => 1,
      };

  /// SMS step 0..1.
  double get smsFraction => stage == HomeSyncStage.sms
      ? 0.95 * scanned / (scanned + 150)
      : (stage == HomeSyncStage.idle ? 0 : 1);

  /// Email step 0..1.
  double get emailFraction => switch (stage) {
        HomeSyncStage.idle || HomeSyncStage.sms => 0,
        HomeSyncStage.email => 0.5,
        _ => 1,
      };

  /// Matching step 0..1.
  double get matchFraction => switch (stage) {
        HomeSyncStage.matching => 0.5,
        HomeSyncStage.done => 1,
        _ => 0,
      };

  /// Result line of the refresh sheet, e.g. `12 new, 2 need review`.
  String get resultLine => reviewCount > 0
      ? '$newCount new, $reviewCount need review'
      : '$newCount new';
}

/// Runs "sync everything": 14-day SMS re-read, email sync, alert checks.
/// Ignored while a sync is already active (FR-17-17).
class HomeSyncNotifier extends Notifier<HomeSyncState> {
  @override
  HomeSyncState build() => const HomeSyncState();

  /// Starts a sync; never throws.
  Future<void> sync() async {
    if (state.running) return;
    state = const HomeSyncState(running: true, stage: HomeSyncStage.sms);
    var read = 0;
    var added = 0;
    var flagged = 0;
    try {
      final scan = ref.read(scanSmsFactoryProvider)(
        (p) => state = HomeSyncState(
          running: true,
          stage: HomeSyncStage.sms,
          scanned: p.scanned,
          found: p.found,
        ),
      );
      final r = await scan(const SmsScanRequest.recent(14));
      read = r.bankMessages;
      added += r.inserted + r.flagged;
      flagged += r.flagged;
    } on Object {
      // Native side missing (tests, desktop).
    }
    state = HomeSyncState(
      running: true,
      stage: HomeSyncStage.email,
      scanned: read,
    );
    try {
      final e = await ref.read(emailSyncRunnerProvider).run();
      added += e.inserted + e.flagged;
      flagged += e.flagged;
    } on Object {
      // Not connected.
    }
    state = HomeSyncState(
      running: true,
      stage: HomeSyncStage.matching,
      scanned: read,
    );
    try {
      await ref.read(alertsEngineProvider).run();
    } on Object {
      // Alerts are best effort.
    }
    state = HomeSyncState(
      done: '$read read',
      stage: HomeSyncStage.done,
      scanned: read,
      newCount: added,
      reviewCount: flagged,
    );
  }
}

/// Home sync state and action (FR-17-17, FR-17-18, FR-17-42).
final homeSyncProvider =
    NotifierProvider<HomeSyncNotifier, HomeSyncState>(HomeSyncNotifier.new);
