import 'dart:async';

import 'package:hisaab/features/home_widget/domain/build_spend_widget_data.dart';
import 'package:hisaab/features/home_widget/domain/widget_updater.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';

/// Keeps the widget in step with the ledger and the hide-amounts setting
/// (FR-30-08, FR-30-10). Updates are debounced so ingest bursts coalesce.
class WidgetSync {
  /// Creates the sync; [clock] and [debounce] are injectable for tests.
  WidgetSync({
    required TransactionRepository transactions,
    required SettingsRepository settings,
    required WidgetUpdater updater,
    DateTime Function()? clock,
    Duration debounce = const Duration(seconds: 2),
  })  : _tx = transactions,
        _settings = settings,
        _updater = updater,
        _clock = clock ?? DateTime.now,
        _debounce = debounce;

  final TransactionRepository _tx;
  final SettingsRepository _settings;
  final WidgetUpdater _updater;
  final DateTime Function() _clock;
  final Duration _debounce;

  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _timer;
  bool _stopped = true;
  int? _today;
  int? _month;
  bool? _hidden;

  /// (Re)subscribes with the current day and month boundaries (local zone).
  void start() {
    stop();
    _stopped = false;
    final now = _clock();
    final dayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    // Far-future upper bound so the live window always reaches "now".
    final to = DateTime(now.year + 1).millisecondsSinceEpoch;
    _subs
      ..add(
        _tx
            .watchTotals(fromMs: dayStart.millisecondsSinceEpoch, toMs: to)
            .listen(
          (t) {
            _today = t.spentMinor + t.investedMinor;
            _schedule();
          },
          onError: (Object _) {},
        ),
      )
      ..add(
        _tx
            .watchTotals(fromMs: monthStart.millisecondsSinceEpoch, toMs: to)
            .listen(
          (t) {
            _month = t.spentMinor + t.investedMinor;
            _schedule();
          },
          onError: (Object _) {},
        ),
      )
      ..add(
        _settings.watch(SettingKeys.hideAmounts).listen(
          (h) {
            _hidden = h;
            _schedule();
          },
          onError: (Object _) {},
        ),
      );
  }

  /// Cancels subscriptions and any pending update.
  void stop() {
    _stopped = true;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    if (_stopped) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(flush()));
  }

  /// Pushes the latest known values now. Never throws (FR-30-10).
  Future<void> flush() async {
    try {
      await _updater.update(
        buildSpendWidgetData(
          todayMinor: _today ?? 0,
          monthMinor: _month ?? 0,
          hidden: _hidden,
          now: _clock(),
        ),
      );
    } on Object {
      // Widget failures never break the app or ingestion.
    }
  }
}
