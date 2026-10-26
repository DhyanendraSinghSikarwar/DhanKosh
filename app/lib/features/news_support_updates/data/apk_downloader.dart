import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_policy.dart';
import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';
import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';

/// User-visible text of a failed checksum (FR-31-21).
const checksumMismatchMessage =
    "The download didn't match its checksum, so it wasn't installed. "
    'Try again.';

/// Downloads the release APK into the cache `updates/` folder and verifies
/// its SHA-256 (FR-31-20, FR-31-21). Only https URLs on GitHub hosts are
/// fetched; redirects are followed by hand up to [maxRedirects].
class ApkDownloader {
  /// Creates the downloader over [http] and the updates folder [dir].
  ApkDownloader({
    required UpdateHttp http,
    required Future<Directory> Function() dir,
    this.maxRedirects = 5,
  })  : _http = http,
        _dir = dir;

  final UpdateHttp _http;
  final Future<Directory> Function() _dir;

  /// Redirect hops allowed per request.
  final int maxRedirects;

  /// Downloads and verifies [release]; returns the verified file. Reports
  /// progress 0..1. Throws [UpdateFailure] or [UpdateCancelled]; a bad file
  /// is deleted.
  Future<File> download(
    Release release, {
    void Function(double progress)? onProgress,
    UpdateCancel? cancel,
  }) async {
    if (!release.installable) {
      throw const UpdateFailure('This release has no installable file.');
    }
    final expected = await _expectedHash(release);
    final dir = await _dir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final target = File('${dir.path}/DhanKosh-${release.version}.apk');
    if (target.existsSync()) {
      if (await sha256Of(target) == expected) {
        onProgress?.call(1);
        return target;
      }
      target.deleteSync();
    }
    await _clean(dir);
    final part = File('${target.path}.part');
    try {
      await _fetchToFile(
        Uri.parse(release.apkUrl),
        part,
        release.sizeBytes,
        onProgress,
        cancel,
      );
      onProgress?.call(1);
      if (await sha256Of(part) != expected) {
        throw const UpdateFailure(checksumMismatchMessage);
      }
      return await part.rename(target.path);
    } on Object {
      if (part.existsSync()) part.deleteSync();
      rethrow;
    }
  }

  /// Deletes stale downloads: partial files and APKs not newer than
  /// [installed] (FR-31-22). Never throws.
  Future<void> cleanStale(String installed) async {
    try {
      final dir = await _dir();
      if (!dir.existsSync()) return;
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final v = RegExp(r'^DhanKosh-(.+)\.apk$').firstMatch(name)?.group(1);
        if (v == null || !isNewer(v, installed)) f.deleteSync();
      }
    } on Object {
      // Cleanup is best effort.
    }
  }

  Future<void> _clean(Directory dir) async {
    for (final f in dir.listSync().whereType<File>()) {
      f.deleteSync();
    }
  }

  Future<String> _expectedHash(Release r) async {
    final inline = r.sha256;
    if (inline != null) return inline.toLowerCase();
    final url = r.sha256Url;
    if (url == null) {
      throw const UpdateFailure(
        "This release has no checksum, so it wasn't installed.",
      );
    }
    final res = await _open(Uri.parse(url));
    try {
      if (res.statusCode != 200) throw const UpdateFailure('Download failed.');
      final text = await utf8.decoder.bind(res.body).join();
      final hash = parseSha256File(text);
      if (hash == null) {
        throw const UpdateFailure("The checksum file isn't valid.");
      }
      return hash;
    } finally {
      res.close();
    }
  }

  Future<void> _fetchToFile(
    Uri url,
    File out,
    int sizeHint,
    void Function(double)? onProgress,
    UpdateCancel? cancel,
  ) async {
    final res = await _open(url);
    final sink = out.openWrite();
    try {
      if (res.statusCode != 200) {
        throw UpdateFailure('Download failed: HTTP ${res.statusCode}');
      }
      final total = res.contentLength > 0 ? res.contentLength : sizeHint;
      var got = 0;
      var last = 0.0;
      await for (final chunk in res.body) {
        if (cancel?.cancelled ?? false) throw const UpdateCancelled();
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 && onProgress != null) {
          final p = (got / total).clamp(0.0, 0.99);
          if (p - last >= 0.01) {
            last = p;
            onProgress(p);
          }
        }
      }
      if (cancel?.cancelled ?? false) throw const UpdateCancelled();
    } on UpdateFailure {
      rethrow;
    } on UpdateCancelled {
      rethrow;
    } on Object {
      throw const UpdateFailure('Download failed. Check your connection.');
    } finally {
      await sink.close();
      res.close();
    }
  }

  /// GET with manual redirects; every hop must pass the allow-list.
  Future<UpdateHttpResponse> _open(Uri start) async {
    var url = start;
    for (var hop = 0; hop <= maxRedirects; hop++) {
      if (!isAllowedUpdateUrl(url)) {
        throw const UpdateFailure(
          "The download address isn't allowed, so nothing was downloaded.",
        );
      }
      final UpdateHttpResponse res;
      try {
        res = await _http.get(url);
      } on Object {
        throw const UpdateFailure('Download failed. Check your connection.');
      }
      final code = res.statusCode;
      if (code >= 300 && code < 400) {
        final loc = res.location;
        res.close();
        if (loc == null || loc.isEmpty) {
          throw const UpdateFailure('Download failed.');
        }
        url = url.resolve(loc);
        continue;
      }
      return res;
    }
    throw const UpdateFailure('Download failed: too many redirects.');
  }
}

/// Lower-case hex SHA-256 of [file], streamed.
Future<String> sha256Of(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
