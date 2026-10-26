import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/portfolio/domain/nav_file.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Downloads the public AMFI NAV text (FR-16-23). Sends nothing about the
/// user. Returns null on any failure.
abstract interface class NavSource {
  /// The file text, or null when it could not be fetched.
  Future<String?> fetch();
}

/// Parses the file text off the UI thread (an isolate in the app).
typedef NavParser = Future<Map<String, NavQuote>> Function(String text);

/// Settings of the optional NAV refresh (FR-16-23). Off by default.
abstract final class NavSettings {
  /// User toggle.
  static const enabled = SettingKey<bool>('nav_refresh_enabled', false);

  /// IST epoch day of the last attempt (throttle: once a day).
  static const lastAttemptDay = SettingKey<int>('nav_last_attempt_day', 0);

  /// Short result of the last run.
  static const lastResult = SettingKey<String>('nav_last_result', '');
}

/// Outcome of a refresh run.
enum NavOutcome { off, throttled, failed, done }

/// Updates mutual fund holdings from the AMFI file by ISIN (FR-16-24).
/// Never throws.
class NavRefreshService {
  /// Creates the service. [now] is epoch ms.
  NavRefreshService({
    required HoldingRepository holdings,
    required SettingsRepository settings,
    required NavSource source,
    required NavParser parse,
    int Function()? now,
  })  : _holdings = holdings,
        _settings = settings,
        _source = source,
        _parse = parse,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final HoldingRepository _holdings;
  final SettingsRepository _settings;
  final NavSource _source;
  final NavParser _parse;
  final int Function() _now;

  static final _isin = RegExp(r'^IN[A-Z0-9]{10}$');

  /// Runs when the toggle is on and today has no attempt yet; [force] (the
  /// Refresh now button) skips the throttle but not the toggle.
  Future<NavOutcome> refresh({bool force = false}) async {
    try {
      if (!await _settings.read(NavSettings.enabled)) return NavOutcome.off;
      final today = (_now() + 19800000) ~/ 86400000;
      if (!force && await _settings.read(NavSettings.lastAttemptDay) == today) {
        return NavOutcome.throttled;
      }
      await _settings.write(NavSettings.lastAttemptDay, today);
      final text = await _source.fetch();
      if (text == null || text.isEmpty) {
        await _settings.write(NavSettings.lastResult, 'Could not download');
        return NavOutcome.failed;
      }
      final quotes = await _parse(text);
      if (quotes.isEmpty) {
        await _settings.write(NavSettings.lastResult, 'File not readable');
        return NavOutcome.failed;
      }
      var n = 0;
      for (final h in await _holdings.list()) {
        if (h.kind != HoldingKind.mutualFund || h.units == null) continue;
        if (!_isin.hasMatch(h.identifier)) continue;
        final q = quotes[h.identifier];
        if (q == null) continue;
        final value = (h.units! * q.nav * 100).round();
        if (await _holdings.applyNav(h.id, valueMinor: value, asOf: q.dateMs)) {
          n++;
        }
      }
      await _settings.write(NavSettings.lastResult, 'Updated $n funds');
      return NavOutcome.done;
    } on Object {
      return NavOutcome.failed;
    }
  }
}
