import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_checker.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';
import 'package:hisaab/features/news_support_updates/domain/upi_link.dart';
import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';

import '../../support/test_env.dart';

const _sha = 'ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12';

Map<String, Object?> _json({String tag = 'v0.2.0'}) => {
      'tag_name': tag,
      'body': 'DhanKosh 0.2.0\n\n- Spend widget\n- News\n\nsha256: $_sha\n',
      'assets': [
        {'name': 'DhanKosh-0.2.0.apk.sha256', 'browser_download_url': 'x'},
        {
          'name': 'DhanKosh-0.2.0.apk',
          'browser_download_url': 'https://example.test/DhanKosh-0.2.0.apk',
          'size': 1234,
        },
      ],
    };

class _Source implements ReleaseSource {
  _Source(this.result);
  final Release? result;
  Exception? error;
  int calls = 0;

  @override
  Future<Release?> latest() async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  test('FR-31-17 isNewer', () {
    expect(isNewer('1.10.0', '1.9.2'), isTrue);
    expect(isNewer('1.9.2', '1.10.0'), isFalse);
    expect(isNewer('2.0', '2.0.0'), isFalse);
    expect(isNewer('2.0.1', '2.0'), isTrue);
    expect(isNewer('1.0.0-beta', '1.0.0'), isFalse);
    expect(isNewer('x.1', '0.1'), isFalse);
  });

  test('FR-31-16 parseRelease picks the apk, strips sha line', () {
    final r = parseRelease(_json())!;
    expect(r.version, '0.2.0');
    expect(r.apkUrl, 'https://example.test/DhanKosh-0.2.0.apk');
    expect(r.sha256, _sha);
    expect(r.sizeBytes, 1234);
    expect(r.notes, isNot(contains('sha256')));
    expect(r.notes, contains('- Spend widget'));
  });

  test('TC-32-05 pipeline notes format parses back', () {
    const notes = 'DhanKosh 0.2.0\n\n- Spend widget\n\nsha256: $_sha\n';
    final r = parseRelease({
      'tag_name': 'v0.2.0',
      'body': notes,
      'assets': [
        {
          'name': 'DhanKosh-0.2.0.apk',
          'browser_download_url': 'https://e.test/a',
        },
      ],
    })!;
    expect(r.sha256, _sha);
    expect(r.notes, 'DhanKosh 0.2.0\n\n- Spend widget');
  });

  test('FR-31-16 no apk asset means no release', () {
    expect(parseRelease({'tag_name': 'v1', 'assets': <Object?>[]}), isNull);
    expect(parseRelease({'tag_name': 'v1'}), isNull);
  });

  test('FR-31-24 cleanReleaseNotes', () {
    final out = cleanReleaseNotes(
      '## New\n- **Bold** [link](http://x) (abc1234)\nFull Changelog: x\n'
      'sha256: $_sha\n\n* plain',
    );
    expect(out, ['New', 'Bold link', 'plain']);
    final many = List.generate(30, (i) => '- line $i').join('\n');
    expect(cleanReleaseNotes(many), hasLength(12));
  });

  test('FR-31-18 throttle gate', () {
    const day = 86400000;
    bool due(int last, int now, {bool en = true, bool force = false}) =>
        updateCheckDue(
          enabled: en,
          lastCheckMs: last,
          nowMs: now,
          force: force,
        );
    expect(due(0, day), isTrue);
    expect(due(1000, 1000 + day - 1), isFalse);
    expect(due(1000, 1000 + day), isTrue);
    expect(due(0, day, en: false), isFalse);
    expect(due(1000, 1001, en: false, force: true), isTrue);
  });

  group('UpdateChecker', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    UpdateChecker make(_Source s, DateTime t) => UpdateChecker(
          source: s,
          settings: env.settings,
          currentVersion: '0.1.0',
          clock: () => t,
        );

    test('available, then throttled for a day, manual bypasses', () async {
      final s = _Source(parseRelease(_json()));
      final t = DateTime(2026, 10, 21, 9);
      final c = make(s, t);
      expect(await c.check(), isA<UpdateAvailable>());
      expect(await c.check(), isNull);
      expect(s.calls, 1);
      expect(await c.check(force: true), isA<UpdateAvailable>());
      expect(
        await make(s, t.add(const Duration(hours: 25))).check(),
        isA<UpdateAvailable>(),
      );
    });

    test('same version is up to date; 404 (null) is up to date', () async {
      final t = DateTime(2026, 10, 21);
      final same = _Source(parseRelease(_json(tag: 'v0.1.0')));
      expect(await make(same, t).check(), isA<UpdateUpToDate>());
      expect(
        await make(_Source(null), t).check(force: true),
        isA<UpdateUpToDate>(),
      );
    });

    test('failure is non-fatal and does not stamp the check time', () async {
      final s = _Source(null)..error = Exception('GitHub answered 500');
      final c = make(s, DateTime(2026, 10, 21));
      final r = await c.check();
      expect(r, isA<UpdateFailed>());
      expect(
        (r! as UpdateFailed).message,
        "Couldn't check for updates: GitHub answered 500",
      );
      expect(await env.settings.read(lastUpdateCheckKey), 0);
    });
  });

  test('FR-31-12 UPI link', () {
    expect(
      buildUpiLink(vpa: 'dummy.user@upi', amountRupees: 200),
      'upi://pay?pa=dummy.user@upi&pn=DhanKosh&cu=INR&am=200',
    );
    expect(
      buildUpiLink(vpa: 'a b@upi'),
      'upi://pay?pa=a%20b@upi&pn=DhanKosh&cu=INR',
    );
    expect(parseSupportAmount('999999'), 999999);
    expect(parseSupportAmount('1234567'), 0);
    expect(parseSupportAmount('12a'), 0);
    expect(parseSupportAmount(''), 0);
  });
}
