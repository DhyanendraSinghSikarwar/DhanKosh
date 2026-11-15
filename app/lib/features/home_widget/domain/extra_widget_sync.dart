import 'dart:async';

import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/home_widget/domain/extra_widget_data.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:parser_core/parser_core.dart';

/// Pushes the extra widgets' payloads (FR-30-16). Never throws.
abstract interface class ExtraWidgetUpdater {
  /// Stores [payload] and redraws the widgets.
  Future<void> update(Map<String, String> payload);
}

/// Keeps the Balance, Budget and Bills widgets current: they follow accounts,
/// budgets and their spend, bills and the hide-amounts setting, debounced so
/// bursts coalesce.
class ExtraWidgetSync {
  /// Creates the sync over the given streams.
  ExtraWidgetSync({
    required Stream<List<AccountWithActivity>> accounts,
    required Stream<List<Budget>> budgets,
    required Stream<Map<Category, int>> categorySpend,
    required Stream<List<RecurringItem>> bills,
    required Stream<bool> hidden,
    required ExtraWidgetUpdater updater,
    DateTime Function()? clock,
    Duration debounce = const Duration(seconds: 2),
  })  : _accounts = accounts,
        _budgets = budgets,
        _spend = categorySpend,
        _bills = bills,
        _hidden = hidden,
        _updater = updater,
        _clock = clock ?? DateTime.now,
        _debounce = debounce;

  final Stream<List<AccountWithActivity>> _accounts;
  final Stream<List<Budget>> _budgets;
  final Stream<Map<Category, int>> _spend;
  final Stream<List<RecurringItem>> _bills;
  final Stream<bool> _hidden;
  final ExtraWidgetUpdater _updater;
  final DateTime Function() _clock;
  final Duration _debounce;

  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _timer;
  bool _stopped = true;

  List<AccountWithActivity>? _acc;
  List<Budget> _bud = const [];
  Map<Category, int> _sp = const {};
  List<RecurringItem> _bi = const [];
  bool? _hide;

  /// Subscribes; call again after the month changes.
  void start() {
    stop();
    _stopped = false;
    void on<T>(Stream<T> s, void Function(T) f) {
      _subs.add(
        s.listen(
          (v) {
            f(v);
            _schedule();
          },
          onError: (Object _) {},
        ),
      );
    }

    on(_accounts, (v) => _acc = v);
    on(_budgets, (v) => _bud = v);
    on(_spend, (v) => _sp = v);
    on(_bills, (v) => _bi = v);
    on(_hidden, (v) => _hide = v);
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

  /// The payload for the current state.
  Map<String, String> payload() {
    final today = _clock();
    var limit = 0;
    var spent = 0;
    for (final b in _bud) {
      limit += b.monthlyLimitMinor;
      spent += _sp[b.category] ?? 0;
    }
    final acc = _acc;
    return {
      ...balancePayload(
        balanceMinor: acc == null ? null : liquidBalanceMinor(acc),
        hidden: _hide,
      ),
      ...budgetPayload(limitMinor: limit, spentMinor: spent, hidden: _hide),
      ...billsPayload(
        [
          for (final r in _bi)
            if (!r.income)
              WidgetBill(
                name: r.name,
                amountMinor: r.amountMinor,
                due: nextDueOf(
                  dayOfMonth: r.dayOfMonth,
                  today: today,
                  month:
                      r.frequency == RecurringFrequency.yearly ? r.month : null,
                ),
              ),
        ],
        hidden: _hide,
      ),
    };
  }

  /// Pushes now. Never throws.
  Future<void> flush() async {
    try {
      await _updater.update(payload());
    } on Object {
      // Widget failures never break the app.
    }
  }
}
