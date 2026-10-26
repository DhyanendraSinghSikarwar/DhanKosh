import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Session lock status (FR-25-03).
enum LockStatus {
  /// Not authenticated yet in this process.
  unknown,

  /// Authenticated.
  unlocked,

  /// Backgrounded since the last unlock.
  locked,
}

/// In-memory lock state; never persisted, so a cold start always locks.
class LockState {
  /// Creates a state.
  const LockState({
    this.status = LockStatus.unknown,
    this.failed = false,
    this.prompting = false,
    this.failures = 0,
    this.retryAt,
  });

  /// Session status.
  final LockStatus status;

  /// Last prompt failed or was cancelled (FR-25-14).
  final bool failed;

  /// A prompt is on screen.
  final bool prompting;

  /// Failed prompts since the last success (FR-25-24).
  final int failures;

  /// Earliest time the next prompt is allowed after repeated failures.
  final DateTime? retryAt;

  /// Whether content must stay hidden.
  bool get needsAuth => status != LockStatus.unlocked;

  /// Copy with changes.
  LockState copyWith({
    LockStatus? status,
    bool? failed,
    bool? prompting,
    int? failures,
    DateTime? retryAt,
  }) =>
      LockState(
        status: status ?? this.status,
        failed: failed ?? this.failed,
        prompting: prompting ?? this.prompting,
        failures: failures ?? this.failures,
        retryAt: retryAt ?? this.retryAt,
      );
}

/// Signature of the prompt call.
typedef AuthenticateFn = Future<bool> Function();

/// Lock rules (memory 25 section 10): lock on pause/hide unless a skip flag
/// is armed; `inactive` never locks; a prompt cancel stays locked.
class LockController extends Notifier<LockState> {
  /// How long a skip flag stays valid (it must not outlive its hop).
  static const skipTtl = Duration(seconds: 60);

  /// Failures allowed before a delay (FR-25-24).
  static const freeAttempts = 5;

  /// First delay; doubles per further failure, capped at [maxDelay].
  static const baseDelay = Duration(seconds: 30);

  /// Longest delay.
  static const maxDelay = Duration(minutes: 5);

  DateTime? _skipUntil;
  DateTime? _awaySince;

  /// Called after a success that followed failures (FR-25-25).
  Future<void> Function(int failures)? onRecoveredAfterFailures;

  /// Test hook.
  DateTime Function() now = DateTime.now;

  /// Prompt call (overridable in tests).
  late AuthenticateFn authenticate;

  @override
  LockState build() {
    authenticate = ref.read(appLockServiceProvider).authenticate;
    onRecoveredAfterFailures = (n) => ref.read(activityLoggerProvider).record(
          ActivityEntry(
            at: DateTime.now(),
            source: ActivitySource.problems,
            error: 'UnlockFailed',
            note: '$n failed unlock attempts',
          ),
        );
    return const LockState();
  }

  /// Arms a one-shot skip before a deliberate hop to a system UI
  /// (FR-25-06): file picker, consent page, settings, installer.
  void skipNextLock() => _skipUntil = now().add(skipTtl);

  /// Marks the session unlocked (FR-25-07: lock just switched on).
  void markUnlocked() => state = const LockState(status: LockStatus.unlocked);

  /// Locks at once (FR-25-22, the Lock now button).
  void lockNow() {
    if (state.status != LockStatus.locked) {
      state = state.copyWith(status: LockStatus.locked, failed: false);
      AppLog.instance.info(LogCategory.ui, 'lock.locked_now');
    }
  }

  /// Maps lifecycle events to locking (FR-25-03, FR-25-06, FR-25-21).
  /// [timeoutMinutes] 0 locks as soon as the app leaves; above 0 it locks on
  /// return only when the app was away at least that long.
  void onLifecycle(
    AppLifecycleState s, {
    required bool enabled,
    int timeoutMinutes = 0,
  }) {
    if (!enabled) return;
    // The skip covers the whole hop (Android sends hidden then paused), so it
    // is cleared on resume, not on the first background event.
    if (s == AppLifecycleState.resumed) {
      _skipUntil = null;
      final since = _awaySince;
      _awaySince = null;
      if (since != null &&
          state.status == LockStatus.unlocked &&
          now().difference(since) >= Duration(minutes: timeoutMinutes)) {
        state = state.copyWith(status: LockStatus.locked);
        AppLog.instance.info(LogCategory.ui, 'lock.locked_timeout');
      }
      return;
    }
    if (s != AppLifecycleState.paused && s != AppLifecycleState.hidden) return;
    final skip = _skipUntil;
    if (skip != null && now().isBefore(skip)) return;
    _skipUntil = null;
    if (state.status != LockStatus.unlocked) return;
    if (timeoutMinutes <= 0) {
      state = state.copyWith(status: LockStatus.locked);
      AppLog.instance.info(LogCategory.ui, 'lock.locked');
    } else {
      _awaySince ??= now();
    }
  }

  /// Seconds left before another prompt is allowed; 0 when none.
  int waitSeconds() {
    final r = state.retryAt;
    if (r == null) return 0;
    final left = r.difference(now());
    return left.isNegative ? 0 : (left.inMilliseconds + 999) ~/ 1000;
  }

  /// Fires the prompt; one at a time (FR-25-04). After [freeAttempts]
  /// failures a growing delay applies (FR-25-24).
  Future<void> unlock() async {
    if (state.prompting || state.status == LockStatus.unlocked) return;
    if (waitSeconds() > 0) return;
    state = state.copyWith(prompting: true);
    var ok = false;
    try {
      ok = await authenticate();
    } on Object {
      ok = false;
    }
    if (ok) {
      final failures = state.failures;
      state = const LockState(status: LockStatus.unlocked);
      if (failures >= 3) {
        try {
          await onRecoveredAfterFailures?.call(failures);
        } on Object {
          // The entry is a courtesy; never block the unlock.
        }
      }
    } else {
      final n = state.failures + 1;
      DateTime? retry;
      if (n >= freeAttempts) {
        final secs =
            baseDelay.inSeconds * (1 << (n - freeAttempts).clamp(0, 4));
        final d = Duration(
          seconds: secs > maxDelay.inSeconds ? maxDelay.inSeconds : secs,
        );
        retry = now().add(d);
      }
      state = state.copyWith(
        prompting: false,
        failed: true,
        failures: n,
        retryAt: retry,
      );
    }
    AppLog.instance.info(
      LogCategory.ui,
      ok ? 'lock.unlocked' : 'lock.auth_failed',
    );
  }
}

/// Lock state provider (keep-alive: the session outlives route changes).
final lockControllerProvider =
    NotifierProvider<LockController, LockState>(LockController.new);
