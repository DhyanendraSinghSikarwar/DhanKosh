import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';

/// App-wide Book: Personal, Business or All (FR-20-23). Home, Transactions,
/// Analysis and Portfolio read it.
class BookNotifier extends Notifier<Book> {
  @override
  Book build() => Book.all;

  /// Switches the book.
  // ignore: use_setters_to_change_properties
  void set(Book b) => state = b;
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
