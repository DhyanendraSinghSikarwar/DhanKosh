/// A published app release (FR-31-16).
class Release {
  /// Creates a release.
  const Release({
    required this.version,
    required this.notes,
    required this.apkUrl,
    this.sizeBytes = 0,
    this.sha256,
  });

  /// `tag_name` without a leading `v`.
  final String version;

  /// Release body without `sha256:` lines.
  final String notes;

  /// Download URL of the `.apk` asset.
  final String apkUrl;

  /// Asset size, bytes.
  final int sizeBytes;

  /// Published SHA-256 (lower-case hex), when present.
  final String? sha256;
}

final _shaPattern = RegExp(r'sha256:\s*([0-9a-fA-F]{64})');

/// Parses a GitHub `releases/latest` JSON object; null when it has no `.apk`
/// asset (FR-31-16). Pure.
Release? parseRelease(Map<String, Object?> json) {
  final assets = json['assets'];
  if (assets is! List) return null;
  Map<String, Object?>? apk;
  for (final a in assets) {
    if (a is Map<String, Object?> &&
        (a['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
      apk = a;
      break;
    }
  }
  if (apk == null) return null;
  final url = apk['browser_download_url'] as String? ?? '';
  var tag = (json['tag_name'] as String? ?? '').trim();
  if (tag.startsWith('v')) tag = tag.substring(1);
  if (url.isEmpty || tag.isEmpty) return null;
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
    sizeBytes: (apk['size'] as num?)?.toInt() ?? 0,
    sha256: sha,
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
