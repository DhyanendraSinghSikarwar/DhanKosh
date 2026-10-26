import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_keys.dart';
import 'package:hisaab/features/news_support_updates/domain/update_policy.dart';
import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Content of the one-time What's new sheet (FR-31-36).
class WhatsNew {
  /// Creates the content.
  const WhatsNew(this.version, this.points);

  /// Installed version.
  final String version;

  /// Cleaned note lines.
  final List<String> points;
}

/// Decides whether the What's new sheet shows after an update and finds its
/// notes: cached history first, then one fetch, else a generic line. Never
/// throws.
class WhatsNewService {
  /// Creates the service for the [current] version.
  WhatsNewService({
    required SettingsRepository settings,
    required ReleaseHistorySource source,
    required this.current,
  })  : _settings = settings,
        _source = source;

  final SettingsRepository _settings;
  final ReleaseHistorySource _source;

  /// Installed version.
  final String current;

  /// The sheet content, or null when nothing should show. Records the
  /// version first so the sheet appears once only.
  Future<WhatsNew?> prepare() async {
    try {
      final last = await _settings.read(lastSeenVersionKey);
      if (last == current) return null;
      await _settings.write(lastSeenVersionKey, current);
      if (!shouldShowWhatsNew(lastSeen: last, current: current)) return null;
      var points = _notes(
        decodeReleaseHistory(await _settings.read(releaseHistoryCacheKey)),
      );
      if (points.isEmpty) {
        try {
          final list = await _source.list().timeout(
                const Duration(seconds: 12),
              );
          await _settings.write(
            releaseHistoryCacheKey,
            encodeReleaseHistory(list),
          );
          points = _notes(list);
        } on Object {
          // Offline: the generic line below.
        }
      }
      return WhatsNew(
        current,
        points.isEmpty ? [whatsNewFallback(current)] : points,
      );
    } on Object {
      return null;
    }
  }

  List<String> _notes(List<Release> all) {
    for (final r in all) {
      if (r.version == current) return cleanReleaseNotes(r.notes);
    }
    return const [];
  }
}
