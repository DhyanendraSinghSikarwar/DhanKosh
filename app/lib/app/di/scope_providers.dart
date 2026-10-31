import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// App-wide Book: Personal, Business or All (FR-20-23). Home, Transactions,
/// Analysis and Portfolio read it.
class BookNotifier extends Notifier<Book> {
  bool _touched = false;

  @override
  Book build() {
    unawaited(_restore());
    return Book.all;
  }

  Future<void> _restore() async {
    try {
      final name = await ref.read(settingsRepositoryProvider).read(
            SettingKeys.book,
          );
      if (!_touched && ref.mounted) {
        state = Book.values.firstWhere(
          (b) => b.name == name,
          orElse: () => Book.all,
        );
      }
    } on Object {
      // No settings store (tests) or unreadable: stay on All books.
    }
  }

  /// Switches the book and remembers it (FR-26-31).
  void set(Book b) {
    _touched = true;
    state = b;
    try {
      unawaited(
        ref
            .read(settingsRepositoryProvider)
            .write(SettingKeys.book, b.name)
            .then((_) {}, onError: (Object _) {}),
      );
    } on Object {
      // Not persisted without a settings store.
    }
  }
}

/// The shared book (FR-20-23).
final bookProvider = NotifierProvider<BookNotifier, Book>(BookNotifier.new);

/// App-wide period (FR-20-22): kind plus custom dates.
class PeriodNotifier extends Notifier<PeriodSelection> {
  @override
  PeriodSelection build() => const PeriodSelection(PeriodKind.thisMonth);

  /// Picks a preset (custom keeps its last dates).
  void set(PeriodKind k) => state = PeriodSelection(
        k,
        customStart: state.customStart,
        customEnd: state.customEnd,
      );

  /// Picks a custom inclusive range.
  void setCustom(DateTime start, DateTime? end) => state = PeriodSelection(
        PeriodKind.custom,
        customStart: start,
        customEnd: end,
      );
}

/// The shared period (FR-20-22).
final periodProvider =
    NotifierProvider<PeriodNotifier, PeriodSelection>(PeriodNotifier.new);

/// Account or card the Analysis is scoped to; null for all (FR-18-27).
class AccountScopeNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// Scopes to [id]; null clears.
  // ignore: use_setters_to_change_properties
  void set(int? id) => state = id;
}

/// The shared account/card scope (FR-18-27).
final accountScopeProvider =
    NotifierProvider<AccountScopeNotifier, int?>(AccountScopeNotifier.new);
