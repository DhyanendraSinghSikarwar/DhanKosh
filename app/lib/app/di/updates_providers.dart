import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/platform_channels/widget_channel.dart';
import 'package:hisaab/features/home_widget/data/widget_updater_impl.dart';
import 'package:hisaab/features/home_widget/domain/widget_sync.dart';
import 'package:hisaab/features/news_support_updates/data/apk_downloader.dart';
import 'package:hisaab/features/news_support_updates/data/channel_apk_installer.dart';
import 'package:hisaab/features/news_support_updates/data/github_release_source.dart';
import 'package:hisaab/features/news_support_updates/data/io_update_http.dart';
import 'package:hisaab/features/news_support_updates/data/news_remote_source.dart';
import 'package:hisaab/features/news_support_updates/data/update_installer.dart';
import 'package:hisaab/features/news_support_updates/data/whats_new_service.dart';
import 'package:hisaab/features/news_support_updates/domain/news.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_checker.dart';
import 'package:hisaab/features/news_support_updates/domain/update_keys.dart';
import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';
import 'package:path_provider/path_provider.dart';

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

/// All-releases lookup; override in tests (FR-31-29).
final releaseHistorySourceProvider = Provider<ReleaseHistorySource>(
  (_) => const GithubReleaseSource(),
);

/// Anonymous downloads; override in tests (FR-31-20).
final updateHttpProvider = Provider<UpdateHttp>((_) => const IoUpdateHttp());

/// Package-installer hand-off over the `widget` channel (FR-31-22).
final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => ChannelApkInstaller(
    ref.watch(widgetChannelProvider),
    ref.watch(lockSkipperProvider),
  ),
);

/// Download, verify and hand off a release; override in tests.
final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => UpdateInstaller(
    downloader: ApkDownloader(
      http: ref.watch(updateHttpProvider),
      dir: () async =>
          Directory('${(await getTemporaryDirectory()).path}/updates'),
    ),
    installer: ref.watch(apkInstallerProvider),
    installed: appVersion,
  ),
);

/// What's new decision and notes (FR-31-36); override in tests.
final whatsNewServiceProvider = Provider<WhatsNewService>(
  (ref) => WhatsNewService(
    settings: ref.watch(settingsRepositoryProvider),
    source: ref.watch(releaseHistorySourceProvider),
    current: appVersion,
  ),
);

/// Update state for the About screen and What's new.
class UpdateController extends Notifier<UpdateState> {
  UpdateCancel? _cancel;

  @override
  UpdateState build() => const UpdateIdle();

  /// Runs a check; the start-up call is gated daily, [force] is manual
  /// (FR-31-18, FR-31-28).
  Future<void> check({bool force = false}) async {
    if (state is UpdateChecking || state is UpdateDownloading) return;
    final before = state;
    if (force) state = const UpdateChecking();
    final next = await ref.read(updateCheckerProvider).check(force: force);
    state = next ?? before;
  }

  /// Downloads, verifies and installs [release] (FR-31-20..22).
  Future<void> install(Release release) async {
    if (state is UpdateDownloading) return;
    final cancel = _cancel = UpdateCancel();
    state = UpdateDownloading(release, 0);
    final next = await ref.read(updateInstallerProvider).run(
      release,
      onProgress: (p) {
        if (!cancel.cancelled) state = UpdateDownloading(release, p);
      },
      cancel: cancel,
    );
    state = next;
  }

  /// Cancels a running download.
  void cancelDownload() => _cancel?.cancel();
}

/// The update state.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Release history list state (FR-31-29, FR-31-30).
class HistoryState {
  /// Creates the state.
  const HistoryState({
    this.releases = const [],
    this.loading = false,
    this.failed = false,
  });

  /// Releases, newest first (live or cached).
  final List<Release> releases;

  /// A fetch is running.
  final bool loading;

  /// The last fetch failed (offline); [releases] is the cached list.
  final bool failed;
}

/// Loads the release history, showing the cached list first and offline.
class ReleaseHistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  /// Loads the cache, then the network.
  Future<void> load() async {
    if (state.loading) return;
    final settings = ref.read(settingsRepositoryProvider);
    var cached = state.releases;
    try {
      if (cached.isEmpty) {
        cached =
            decodeReleaseHistory(await settings.read(releaseHistoryCacheKey));
      }
    } on Object {
      cached = const [];
    }
    state = HistoryState(releases: cached, loading: true);
    try {
      final list = await ref.read(releaseHistorySourceProvider).list();
      await settings.write(releaseHistoryCacheKey, encodeReleaseHistory(list));
      state = HistoryState(releases: list);
    } on Object {
      state = HistoryState(releases: cached, failed: true);
    }
  }
}

/// The release history.
final releaseHistoryProvider =
    NotifierProvider<ReleaseHistoryController, HistoryState>(
  ReleaseHistoryController.new,
);

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
