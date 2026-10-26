import 'dart:convert';

import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';

/// Repository the updater reads (public, anonymous GET).
const releaseRepo = 'DhyanendraSinghSikarwar/DhanKosh';

/// A published app release (FR-31-16).
class Release {
  /// Creates a release.
  const Release({
    required this.version,
    required this.notes,
    required this.apkUrl,
    this.sizeBytes = 0,
    this.sha256,
    this.sha256Url,
    this.publishedAt,
    this.pageUrl,
  });

  /// Reads a release saved by [toJson].
  factory Release.fromJson(Map<String, Object?> j) => Release(
        version: j['v'] as String? ?? '',
        notes: j['n'] as String? ?? '',
        apkUrl: j['a'] as String? ?? '',
        sizeBytes: (j['s'] as num?)?.toInt() ?? 0,
        sha256: j['h'] as String?,
        sha256Url: j['u'] as String?,
        publishedAt: DateTime.tryParse(j['d'] as String? ?? ''),
        pageUrl: j['p'] as String?,
      );

  /// Compact form for the local history cache (FR-31-30).
  Map<String, Object?> toJson() => {
        'v': version,
        'n': notes,
        'a': apkUrl,
        's': sizeBytes,
        'h': sha256,
        'u': sha256Url,
        'd': publishedAt?.toIso8601String(),
        'p': pageUrl,
      };

  /// True when the release carries an installable `.apk` asset.
  bool get installable => apkUrl.isNotEmpty;

  /// `tag_name` without a leading `v`.
  final String version;

  /// Release body without `sha256:` lines.
  final String notes;

  /// Download URL of the `.apk` asset.
  final String apkUrl;

  /// Asset size, bytes.
  final int sizeBytes;

  /// Published SHA-256 (lower-case hex), when present in the notes.
  final String? sha256;

  /// Download URL of the `DhanKosh.apk.sha256` asset, when published.
  final String? sha256Url;

  /// Publication time, when known.
  final DateTime? publishedAt;

  /// Release page on GitHub, when known.
  final String? pageUrl;
}

final _shaPattern = RegExp(r'sha256:\s*([0-9a-fA-F]{64})');

/// Parses a GitHub `releases/latest` JSON object; null when it has no `.apk`
/// asset (FR-31-16). Pure.
Release? parseRelease(Map<String, Object?> json) =>
    _parse(json, requireApk: true);

/// Parses a GitHub `releases` list into the history, newest first; releases
/// without an `.apk` asset stay listed (not installable); drafts and
/// malformed entries are skipped (FR-31-29). Pure.
List<Release> parseReleaseHistory(Object? json) {
  if (json is! List) return const [];
  final out = <Release>[];
  for (final j in json) {
    if (j is Map<String, Object?> && j['draft'] != true) {
      final r = _parse(j, requireApk: false);
      if (r != null) out.add(r);
    }
  }
  out.sort((a, b) {
    final x = a.publishedAt;
    final y = b.publishedAt;
    if (x != null && y != null) return y.compareTo(x);
    return isNewer(a.version, b.version) ? -1 : 1;
  });
  return out;
}

Release? _parse(Map<String, Object?> json, {required bool requireApk}) {
  final assets = json['assets'];
  Map<String, Object?>? apk;
  String? shaUrl;
  if (assets is List) {
    for (final a in assets) {
      if (a is! Map<String, Object?>) continue;
      final name = (a['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk.sha256')) {
        shaUrl ??= a['browser_download_url'] as String?;
      } else if (apk == null && name.endsWith('.apk')) {
        apk = a;
      }
    }
  }
  if (apk == null && requireApk) return null;
  final url = apk?['browser_download_url'] as String? ?? '';
  var tag = (json['tag_name'] as String? ?? '').trim();
  if (tag.startsWith('v')) tag = tag.substring(1);
  if ((requireApk && url.isEmpty) || tag.isEmpty) return null;
  final body = json['body'] as String? ?? '';
  final sha = _shaPattern.firstMatch(body)?.group(1)?.toLowerCase();
  final notes = body
      .split('\n')
      .where((l) => !l.trimLeft().toLowerCase().startsWith('sha256:'))
      .join('\n')
      .trim();
  return Release(
    version: tag,
    notes: notes,
    apkUrl: url,
    sizeBytes: (apk?['size'] as num?)?.toInt() ?? 0,
    sha256: sha,
    sha256Url: shaUrl,
    publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    pageUrl: json['html_url'] as String?,
  );
}

/// Cleans release notes for the What's new sheet (FR-31-24): drops
/// `sha256:` and `full changelog` lines, links, markdown marks and commit
/// hashes; at most [maxLines] lines.
List<String> cleanReleaseNotes(String body, {int maxLines = 12}) {
  final out = <String>[];
  for (final raw in body.split('\n')) {
    var l = raw.trim();
    final low = l.toLowerCase();
    if (low.startsWith('sha256:') || low.startsWith('full changelog')) continue;
    l = l
        .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceFirst(RegExp('^#+'), '')
        .replaceFirst(RegExp(r'^[-*+]\s+'), '')
        .replaceAll(RegExp('[*_`]+'), '')
        .replaceAll(RegExp(r'\(?\b[0-9a-f]{7,40}\b\)?'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (l.isEmpty) continue;
    out.add(l);
    if (out.length == maxLines) break;
  }
  return out;
}

/// JSON text of [releases] for the local history cache (FR-31-30).
String encodeReleaseHistory(List<Release> releases) =>
    jsonEncode([for (final r in releases) r.toJson()]);

/// Reads a cache written by [encodeReleaseHistory]; empty on any problem.
List<Release> decodeReleaseHistory(String text) {
  if (text.isEmpty) return const [];
  try {
    final j = jsonDecode(text);
    if (j is! List) return const [];
    return [
      for (final e in j)
        if (e is Map<String, Object?>) Release.fromJson(e),
    ];
  } on FormatException {
    return const [];
  }
}
