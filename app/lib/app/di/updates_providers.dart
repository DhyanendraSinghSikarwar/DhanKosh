import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/platform_channels/widget_channel.dart';
import 'package:hisaab/features/home_widget/data/widget_updater_impl.dart';
import 'package:hisaab/features/home_widget/domain/widget_sync.dart';
import 'package:hisaab/features/news_support_updates/data/github_release_source.dart';
import 'package:hisaab/features/news_support_updates/data/news_remote_source.dart';
import 'package:hisaab/features/news_support_updates/domain/news.dart';
import 'package:hisaab/features/news_support_updates/domain/update_checker.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';

// F-30 widget, F-31 news/support/updates wiring.

/// Installed version; the release workflow passes `--dart-define`.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

/// Donation UPI id from build configuration; empty hides Support (FR-31-10).
const supportUpiId = String.fromEnvironment('SUPPORT_UPI_ID');

/// Native hand-offs (browser, UPI, release page); override in tests.
final widgetChannelProvider = Provider<WidgetChannel>(
  (_) => const WidgetChannel(),
);

/// Keeps the home-screen widget current (FR-30-08).
final widgetSyncProvider = Provider<WidgetSync>((ref) {
  final sync = WidgetSync(
    transactions: ref.watch(transactionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    updater: const HomeWidgetUpdater(),
  );
  ref.onDispose(sync.stop);
  return sync;
});

/// Release lookup; override in tests.
final releaseSourceProvider = Provider<ReleaseSource>(
  (_) => const GithubReleaseSource(),
);

/// Daily-throttled checker.
final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => UpdateChecker(
    source: ref.watch(releaseSourceProvider),
    settings: ref.watch(settingsRepositoryProvider),
    currentVersion: appVersion,
  ),
);

/// Update state for the About screen and What's new.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateIdle();

  /// Runs a check; the start-up call is gated daily, [force] is manual.
  Future<void> check({bool force = false}) async {
    if (state is UpdateChecking) return;
    final before = state;
    if (force) state = const UpdateChecking();
    final next = await ref.read(updateCheckerProvider).check(force: force);
    state = next ?? before;
  }
}

/// The update state.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// News tab state.
class NewsState {
  /// Creates the state.
  const NewsState({
    this.feed = NewsFeed.latest,
    this.items = const [],
    this.loading = false,
    this.failed = false,
  });

  /// Selected tab.
  final NewsFeed feed;

  /// Headlines.
  final List<Headline> items;

  /// Load in flight.
  final bool loading;

  /// Last load failed.
  final bool failed;
}

/// Loads news with a 10 minute in-memory cache per tab (FR-31-05).
class NewsController extends Notifier<NewsState> {
  final Map<NewsFeed, (DateTime, List<Headline>)> _cache = {};

  @override
  NewsState build() => const NewsState();

  /// Selects [feed] and loads it.
  Future<void> load(NewsFeed feed, {bool force = false}) async {
    final hit = _cache[feed];
    if (!force &&
        hit != null &&
        DateTime.now().difference(hit.$1) < const Duration(minutes: 10)) {
      state = NewsState(feed: feed, items: hit.$2);
      return;
    }
    state = NewsState(
      feed: feed,
      items: force ? state.items : const [],
      loading: true,
    );
    try {
      final items = await loadNews(feed);
      _cache[feed] = (DateTime.now(), items);
      if (state.feed == feed) state = NewsState(feed: feed, items: items);
    } on Object {
      if (state.feed == feed) state = NewsState(feed: feed, failed: true);
    }
  }
}

/// The news state.
final newsControllerProvider =
    NotifierProvider<NewsController, NewsState>(NewsController.new);
