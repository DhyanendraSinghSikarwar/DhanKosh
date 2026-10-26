import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/dashboard_home/domain/home_attention.dart';
import 'package:hisaab/features/news_support_updates/data/apk_downloader.dart';
import 'package:hisaab/features/news_support_updates/data/update_installer.dart';
import 'package:hisaab/features/news_support_updates/data/whats_new_service.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_checker.dart';
import 'package:hisaab/features/news_support_updates/domain/update_keys.dart';
import 'package:hisaab/features/news_support_updates/domain/update_policy.dart';
import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';

import '../../support/test_env.dart';

// sha256 of the ASCII bytes "abc" (fixture file content).
const _abc = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const _apk = 'https://github.com/o/r/releases/download/v0.3.0/DhanKosh.apk';
const _shaUrl =
    'https://github.com/o/r/releases/download/v0.3.0/DhanKosh.apk.sha256';
const _cdn = 'https://objects.githubusercontent.com/blob/abc';

Release _release({
  String version = '0.3.0',
  String? sha256Url = _shaUrl,
  String apkUrl = _apk,
}) =>
    Release(
      version: version,
      notes: '- Fixture note',
      apkUrl: apkUrl,
      sizeBytes: 3,
      sha256Url: sha256Url,
    );

class _Res implements UpdateHttpResponse {
  _Res(this.statusCode, {this.location, this.data = const [], this.chunks = 1});

  @override
  final int statusCode;
  @override
  final String? location;
  final List<int> data;
  final int chunks;
  bool closed = false;

  @override
  int get contentLength => data.length;

  @override
  Stream<List<int>> get body async* {
    final n = (data.length / chunks).ceil().clamp(1, 1 << 30);
    for (var i = 0; i < data.length; i += n) {
      yield data.sublist(i, (i + n).clamp(0, data.length));
    }
  }

  @override
  void close() => closed = true;
}

class _FakeHttp implements UpdateHttp {
  final routes = <String, _Res Function()>{};
  final requested = <String>[];

  @override
  Future<UpdateHttpResponse> get(Uri url) async {
    requested.add(url.toString());
    final r = routes[url.toString()];
    if (r == null) throw const SocketException('offline');
    return r();
  }
}

class _FakeInstaller implements ApkInstaller {
  _FakeInstaller([this.result = InstallHandoff.started]);
  final InstallHandoff result;
  final paths = <String>[];

  @override
  Future<InstallHandoff> install(String path) async {
    paths.add(path);
    return result;
  }
}

class _Source implements ReleaseHistorySource, ReleaseSource {
  _Source({this.list_ = const [], this.fail = false});
  final List<Release> list_;
  final bool fail;
  int calls = 0;

  @override
  Future<List<Release>> list() async {
    calls++;
    if (fail) throw Exception('offline');
    return list_;
  }

  @override
  Future<Release?> latest() async => list_.isEmpty ? null : list_.first;
}

Map<String, Object?> _gh(
  String tag,
  String date, {
  bool apk = true,
  bool draft = false,
  String body = '- Note',
}) =>
    {
      'tag_name': tag,
      'draft': draft,
      'published_at': date,
      'html_url': 'https://github.com/o/r/releases/tag/$tag',
      'body': body,
      'assets': [
        if (apk) ...[
          {
            'name': 'DhanKosh.apk',
            'browser_download_url':
                'https://github.com/o/r/d/$tag/DhanKosh.apk',
            'size': 10,
          },
          {
            'name': 'DhanKosh.apk.sha256',
            'browser_download_url':
                'https://github.com/o/r/d/$tag/DhanKosh.apk.sha256',
          },
        ],
      ],
    };

void main() {
  group('policy', () {
    test('FR-31-21 host allow-list', () {
      bool ok(String u) => isAllowedUpdateUrl(Uri.parse(u));
      expect(ok('https://github.com/a/b/DhanKosh.apk'), isTrue);
      expect(ok('https://objects.githubusercontent.com/x'), isTrue);
      expect(ok('https://release-assets.githubusercontent.com/x'), isTrue);
      expect(ok('http://github.com/a'), isFalse);
      expect(ok('https://evil.test/github.com'), isFalse);
      expect(ok('https://github.com.evil.test/a'), isFalse);
      expect(ok('https://notgithubusercontent.com/a'), isFalse);
      expect(ok('https://user@github.com/a'), isFalse);
      expect(ok('ftp://github.com/a'), isFalse);
    });

    test('FR-31-22 downgrade and equal versions are refused', () {
      bool may(String c, String i) => mayInstall(candidate: c, installed: i);
      expect(may('0.3.0', '0.2.0'), isTrue);
      expect(may('1.10.0', '1.9.2'), isTrue);
      expect(may('0.2.0', '0.2.0'), isFalse);
      expect(may('0.1.0', '0.2.0'), isFalse);
    });

    test('FR-31-21 checksum file parsing is hex only', () {
      expect(parseSha256File('${_abc.toUpperCase()}\n'), _abc);
      expect(parseSha256File('$_abc  DhanKosh.apk'), _abc);
      expect(parseSha256File('abc'), isNull);
      expect(parseSha256File('${_abc}0'), isNull);
    });

    test("FR-31-36 What's new only after an upgrade", () {
      bool show(String l, String c) =>
          shouldShowWhatsNew(lastSeen: l, current: c);
      expect(show('', '0.3.0'), isFalse);
      expect(show('0.2.0', '0.3.0'), isTrue);
      expect(show('0.3.0', '0.3.0'), isFalse);
      expect(show('0.3.0', '0.2.0'), isFalse);
    });
  });

  group('release history', () {
    test('FR-31-29 parses newest first, keeps asset-less, skips drafts', () {
      final list = parseReleaseHistory([
        _gh('v0.1.0', '2026-10-01T10:00:00Z'),
        _gh('v0.3.0', '2026-10-25T10:00:00Z'),
        _gh('v0.2.0', '2026-10-10T10:00:00Z', apk: false),
        _gh('v9.9.9', '2026-10-26T10:00:00Z', draft: true),
        'junk',
      ]);
      expect(list.map((r) => r.version), ['0.3.0', '0.2.0', '0.1.0']);
      expect(list.first.sha256Url, endsWith('DhanKosh.apk.sha256'));
      expect(list.first.apkUrl, endsWith('DhanKosh.apk'));
      expect(list.first.publishedAt, DateTime.utc(2026, 10, 25, 10));
      expect(list[1].installable, isFalse);
      expect(parseReleaseHistory({'not': 'a list'}), isEmpty);
    });

    test('FR-31-30 cache round trip, bad cache is empty', () {
      final list = parseReleaseHistory([_gh('v0.3.0', '2026-10-25T10:00:00Z')]);
      final back = decodeReleaseHistory(encodeReleaseHistory(list));
      expect(back.single.version, '0.3.0');
      expect(back.single.sha256Url, list.single.sha256Url);
      expect(back.single.publishedAt, list.single.publishedAt);
      expect(decodeReleaseHistory('{oops'), isEmpty);
      expect(decodeReleaseHistory(''), isEmpty);
    });
  });

  group('ApkDownloader', () {
    late Directory dir;
    late _FakeHttp http;
    late ApkDownloader dl;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dk_upd_');
      http = _FakeHttp();
      http.routes[_shaUrl] = () => _Res(200, data: utf8.encode('$_abc\n'));
      http.routes[_apk] = () => _Res(302, location: _cdn);
      http.routes[_cdn] = () => _Res(200, data: utf8.encode('abc'), chunks: 3);
      dl = ApkDownloader(http: http, dir: () async => dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('FR-31-20 follows a redirect, reports progress, verifies', () async {
      final seen = <double>[];
      final f = await dl.download(_release(), onProgress: seen.add);
      expect(f.path, endsWith('DhanKosh-0.3.0.apk'));
      expect(await f.readAsString(), 'abc');
      expect(seen.last, 1.0);
      expect(seen, orderedEquals([...seen]..sort()));
      expect(http.requested, [_shaUrl, _apk, _cdn]);
      expect(dir.listSync().length, 1);
    });

    test('FR-31-21 mismatch deletes the file and refuses', () async {
      http.routes[_shaUrl] =
          () => _Res(200, data: utf8.encode('${'0' * 64}\n'));
      await expectLater(
        dl.download(_release()),
        throwsA(
          isA<UpdateFailure>()
              .having((e) => e.message, 'm', checksumMismatchMessage),
        ),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('FR-31-21 no checksum asset is refused before any download', () async {
      await expectLater(
        dl.download(_release(sha256Url: null)),
        throwsA(isA<UpdateFailure>()),
      );
      expect(http.requested, isEmpty);
    });

    test('FR-31-20 redirect limit', () async {
      http.routes[_cdn] = () => _Res(302, location: _cdn);
      await expectLater(
        dl.download(_release()),
        throwsA(
          isA<UpdateFailure>()
              .having((e) => e.message, 'm', contains('redirects')),
        ),
      );
      // 1 sha + apk + (maxRedirects + 1) hops on the loop.
      expect(http.requested.where((u) => u == _cdn).length, 5);
    });

    test('FR-31-21 redirect to a foreign host or http is refused', () async {
      http.routes[_apk] = () => _Res(302, location: 'https://evil.test/a.apk');
      await expectLater(
        dl.download(_release()),
        throwsA(isA<UpdateFailure>()),
      );
      expect(http.requested, isNot(contains('https://evil.test/a.apk')));
      http.routes[_apk] = () => _Res(302, location: 'http://github.com/a.apk');
      await expectLater(dl.download(_release()), throwsA(isA<UpdateFailure>()));
    });

    test('FR-31-21 apk url on a foreign host is never requested', () async {
      await expectLater(
        dl.download(_release(apkUrl: 'https://evil.test/DhanKosh.apk')),
        throwsA(isA<UpdateFailure>()),
      );
      expect(http.requested, [_shaUrl]);
    });

    test('FR-31-20 cancel stops the download and leaves no file', () async {
      // Cancel in the middle of the stream.
      final mid = UpdateCancel();
      await expectLater(
        dl.download(_release(), cancel: mid, onProgress: (_) => mid.cancel()),
        throwsA(isA<UpdateCancelled>()),
      );
      expect(dir.listSync(), isEmpty);
      // Cancel before start: first chunk check throws.
      final c2 = UpdateCancel()..cancel();
      await expectLater(
        dl.download(_release(), cancel: c2),
        throwsA(isA<UpdateCancelled>()),
      );
      expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
    });

    test('FR-31-22 stale files are cleaned', () async {
      File('${dir.path}/DhanKosh-0.2.0.apk').writeAsStringSync('x');
      File('${dir.path}/DhanKosh-0.4.0.apk.part').writeAsStringSync('x');
      File('${dir.path}/DhanKosh-0.4.0.apk').writeAsStringSync('x');
      await dl.cleanStale('0.3.0');
      expect(
        dir.listSync().map((f) => f.uri.pathSegments.last),
        ['DhanKosh-0.4.0.apk'],
      );
    });
  });

  group('UpdateInstaller', () {
    late Directory dir;
    late _FakeHttp http;
    late _FakeInstaller native;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dk_upd_');
      http = _FakeHttp();
      http.routes[_shaUrl] = () => _Res(200, data: utf8.encode(_abc));
      http.routes[_apk] = () => _Res(200, data: utf8.encode('abc'));
      native = _FakeInstaller();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    UpdateInstaller make({String installed = '0.2.0', _FakeInstaller? n}) =>
        UpdateInstaller(
          downloader: ApkDownloader(http: http, dir: () async => dir),
          installer: n ?? native,
          installed: installed,
        );

    test('FR-31-22 hands a verified file over and keeps it', () async {
      final s = await make().run(_release());
      expect(s, isA<UpdateHandedOff>());
      expect(native.paths.single, endsWith('DhanKosh-0.3.0.apk'));
      expect(File(native.paths.single).existsSync(), isTrue);
    });

    test('FR-31-22 downgrade and equal version never download', () async {
      for (final installed in ['0.3.0', '0.9.0']) {
        final s = await make(installed: installed).run(_release());
        expect(s, isA<UpdateFailed>());
      }
      expect(http.requested, isEmpty);
      expect(native.paths, isEmpty);
    });

    test('FR-31-21 checksum mismatch: not installed, message shown', () async {
      http.routes[_shaUrl] = () => _Res(200, data: utf8.encode('1' * 64));
      final s = await make().run(_release());
      expect(
        s,
        isA<UpdateFailed>()
            .having((f) => f.message, 'm', checksumMismatchMessage)
            .having((f) => f.release?.version, 'r', '0.3.0'),
      );
      expect(native.paths, isEmpty);
      expect(dir.listSync(), isEmpty);
    });

    test('FR-31-22 permission needed is reported', () async {
      final s = await make(
        n: _FakeInstaller(InstallHandoff.permissionNeeded),
      ).run(_release());
      expect(s, isA<UpdatePermissionNeeded>());
    });

    test('FR-31-20 cancel returns to available', () async {
      final c = UpdateCancel()..cancel();
      final s = await make().run(_release(), cancel: c);
      expect(s, isA<UpdateAvailable>());
      expect(native.paths, isEmpty);
    });

    test('FR-31-26 offline is a failure, not a throw', () async {
      http.routes.remove(_shaUrl);
      final s = await make().run(_release());
      expect(s, isA<UpdateFailed>());
    });
  });

  group('checker keeps the known version', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    test('FR-31-28 manual check bypasses the throttle; known is stored',
        () async {
      final src = _Source(list_: [_release()]);
      final now = DateTime(2026, 10, 26, 9);
      final c = UpdateChecker(
        source: src,
        settings: env.settings,
        currentVersion: '0.2.0',
        clock: () => now,
      );
      expect(await c.check(), isA<UpdateAvailable>());
      expect(await env.settings.read(knownUpdateKey), '0.3.0');
      expect(await c.check(), isNull);
      expect(await c.check(force: true), isA<UpdateAvailable>());
      final same = UpdateChecker(
        source: src,
        settings: env.settings,
        currentVersion: '0.3.0',
        clock: () => now,
      );
      expect(await same.check(force: true), isA<UpdateUpToDate>());
      expect(await env.settings.read(knownUpdateKey), '');
    });
  });

  group('WhatsNewService', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    WhatsNewService make(_Source s) => WhatsNewService(
          settings: env.settings,
          source: s,
          current: '0.3.0',
        );

    test('FR-31-36 fresh install records the version, shows nothing', () async {
      final s = _Source();
      expect(await make(s).prepare(), isNull);
      expect(await env.settings.read(lastSeenVersionKey), '0.3.0');
      expect(s.calls, 0);
    });

    test('FR-31-36 after an update: cached notes, once only', () async {
      await env.settings.write(lastSeenVersionKey, '0.2.0');
      await env.settings.write(
        releaseHistoryCacheKey,
        encodeReleaseHistory([
          const Release(version: '0.3.0', notes: '- New thing', apkUrl: ''),
        ]),
      );
      final s = _Source();
      final w = await make(s).prepare();
      expect(w!.points, ['New thing']);
      expect(s.calls, 0);
      expect(await make(s).prepare(), isNull);
    });

    test('FR-31-36 fetches when uncached, generic line when offline', () async {
      await env.settings.write(lastSeenVersionKey, '0.2.0');
      final online = _Source(
        list_: [
          const Release(version: '0.3.0', notes: '- From net', apkUrl: ''),
        ],
      );
      expect((await make(online).prepare())!.points, ['From net']);
      expect(online.calls, 1);

      await env.settings.write(lastSeenVersionKey, '0.2.0');
      await env.settings.write(releaseHistoryCacheKey, '');
      final off = await make(_Source(fail: true)).prepare();
      expect(off!.points, [whatsNewFallback('0.3.0')]);
    });
  });

  group('update alert', () {
    const on = AlertSettings();

    test('FR-31-34 one notification per version, default on', () {
      final d = AlertRules.updateAvailable(
        version: '0.3.0',
        installed: '0.2.0',
        settings: on,
        alerted: {},
      )!;
      expect(d.title, 'DhanKosh 0.3.0 is available');
      expect(d.key, 'update:0.3.0');
      expect(alertRouteFor(d.link), '/settings/updates');
      expect(
        AlertRules.updateAvailable(
          version: '0.3.0',
          installed: '0.2.0',
          settings: on,
          alerted: {d.key},
        ),
        isNull,
      );
      expect(
        AlertRules.updateAvailable(
          version: '0.4.0',
          installed: '0.2.0',
          settings: on,
          alerted: {d.key},
        ),
        isNotNull,
      );
    });

    test('FR-31-34 toggle off, not newer and empty give nothing', () {
      AlertDecision? run(String v, String i, AlertSettings s) =>
          AlertRules.updateAvailable(
            version: v,
            installed: i,
            settings: s,
            alerted: {},
          );
      expect(
        run('0.3.0', '0.2.0', const AlertSettings(updateAvailable: false)),
        isNull,
      );
      expect(run('0.2.0', '0.2.0', on), isNull);
      expect(run('0.1.0', '0.2.0', on), isNull);
      expect(run('', '0.2.0', on), isNull);
    });
  });

  group('Home notice rows', () {
    test('FR-31-33 update row only with a version', () {
      List<AttentionItem> rows(String? v) => buildAttention(
            reviewCount: 0,
            bills: const [],
            lockedStatements: 0,
            unreadableStatements: 0,
            cards: const [],
            updateVersion: v,
          );
      expect(rows(null), isEmpty);
      final r = rows('0.3.0').single;
      expect(r.kind, AttentionKind.update);
      expect(r.title, 'Update 0.3.0 available');
      expect(r.route, '/settings/updates');
      expect(r.dismissVersion, '0.3.0');
    });
  });
}
