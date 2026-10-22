import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/security_providers.dart';

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
  });

  /// Session status.
  final LockStatus status;

  /// Last prompt failed or was cancelled (FR-25-14).
  final bool failed;

  /// A prompt is on screen.
  final bool prompting;

  /// Whether content must stay hidden.
  bool get needsAuth => status != LockStatus.unlocked;

  /// Copy with changes.
  LockState copyWith({LockStatus? status, bool? failed, bool? prompting}) =>
      LockState(
        status: status ?? this.status,
        failed: failed ?? this.failed,
        prompting: prompting ?? this.prompting,
      );
}

/// Signature of the prompt call.
typedef AuthenticateFn = Future<bool> Function();

/// Lock rules (memory 25 section 10): lock on pause/hide unless a skip flag
/// is armed; `inactive` never locks; a prompt cancel stays locked.
class LockController extends Notifier<LockState> {
  /// How long a skip flag stays valid (it must not outlive its hop).
  static const skipTtl = Duration(seconds: 60);

  DateTime? _skipUntil;

  /// Test hook.
  DateTime Function() now = DateTime.now;

  /// Prompt call (overridable in tests).
  late AuthenticateFn authenticate;

  @override
  LockState build() {
    authenticate = ref.read(appLockServiceProvider).authenticate;
    return const LockState();
  }

  /// Arms a one-shot skip before a deliberate hop to a system UI
  /// (FR-25-06): file picker, consent page, settings, installer.
  void skipNextLock() => _skipUntil = now().add(skipTtl);

  /// Marks the session unlocked (FR-25-07: lock just switched on).
  void markUnlocked() => state = const LockState(status: LockStatus.unlocked);

  /// Maps lifecycle events to locking (FR-25-03, FR-25-06).
  void onLifecycle(AppLifecycleState s, {required bool enabled}) {
    if (!enabled) return;
    // The skip covers the whole hop (Android sends hidden then paused), so it
    // is cleared on resume, not on the first background event.
    if (s == AppLifecycleState.resumed) {
      _skipUntil = null;
      return;
    }
    if (s != AppLifecycleState.paused && s != AppLifecycleState.hidden) return;
    final skip = _skipUntil;
    if (skip != null && now().isBefore(skip)) return;
    _skipUntil = null;
    if (state.status == LockStatus.unlocked) {
      state = state.copyWith(status: LockStatus.locked);
    }
  }

  /// Fires the prompt; one at a time (FR-25-04).
  Future<void> unlock() async {
    if (state.prompting || state.status == LockStatus.unlocked) return;
    state = state.copyWith(prompting: true);
    var ok = false;
    try {
      ok = await authenticate();
    } on Object {
      ok = false;
    }
    state = ok
        ? const LockState(status: LockStatus.unlocked)
        : state.copyWith(prompting: false, failed: true);
  }
}

/// Lock state provider (keep-alive: the session outlives route changes).
final lockControllerProvider =
    NotifierProvider<LockController, LockState>(LockController.new);
