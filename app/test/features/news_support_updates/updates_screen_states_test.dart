import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/core/platform_channels/widget_channel.dart';
import 'package:hisaab/features/news_support_updates/data/apk_downloader.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_keys.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';
import 'package:hisaab/features/news_support_updates/presentation/updates_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/whats_new_sheet.dart';

import '../../support/test_env.dart';

class _Channel extends WidgetChannel {
  final opened = <String>[];

  @override
  Future<bool> openUrl(
    String url, {
    bool chooser = false,
    String chooserTitle = 'Open with',
  }) async {
    opened.add(url);
    return true;
  }
}

class _Ctl extends UpdateController {
  _Ctl(this.initial);
  final UpdateState initial;
  final checks = <bool>[];
  final installs = <String>[];
  int cancels = 0;

  @override
  UpdateState build() => initial;

  @override
  Future<void> check({bool force = false}) async {
    checks.add(force);
    state = const UpdateChecking();
  }

  @override
  Future<void> install(Release release) async => installs.add(release.version);

  @override
  void cancelDownload() => cancels++;
}

class _Hist extends ReleaseHistoryController {
  _Hist(this.initial);
  final HistoryState initial;

  @override
  HistoryState build() => initial;

  @override
  Future<void> load() async {}
}

const _new = Release(
  version: '0.3.0',
  notes: '- Fixture feature',
  apkUrl: 'https://github.com/o/r/d/DhanKosh.apk',
);
const _cur = Release(version: '0.1.0', notes: '- First', apkUrl: '');

Future<_Ctl> _pump(
  WidgetTester t,
  UpdateState s, {
  HistoryState h = const HistoryState(),
  _Channel? ch,
}) async {
  final ctl = _Ctl(s);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        updateControllerProvider.overrideWith(() => ctl),
        releaseHistoryProvider.overrideWith(() => _Hist(h)),
        widgetChannelProvider.overrideWithValue(ch ?? _Channel()),
      ],
      child: const MaterialApp(home: UpdatesScreen()),
    ),
  );
  return ctl;
}

void main() {
  testWidgets('FR-31-28 manual check passes force and shows Checking...',
      (t) async {
    final ctl = await _pump(t, const UpdateIdle());
    await t.tap(find.byKey(const Key('check-updates')));
    await t.pump();
    expect(ctl.checks, [true]);
    expect(find.text('Checking...'), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(find.byKey(const Key('check-updates')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('FR-31-28 latest shows the installed version', (t) async {
    await _pump(t, const UpdateUpToDate());
    expect(find.text('You are on the latest (0.1.0)'), findsOneWidget);
  });

  testWidgets('FR-31-28 error and offline messages are shown', (t) async {
    await _pump(
      t,
      const UpdateFailed("Couldn't check for updates: no connection"),
    );
    expect(
      find.text("Couldn't check for updates: no connection"),
      findsOneWidget,
    );
  });

  testWidgets('FR-31-22 available offers Download and install', (t) async {
    final ctl = await _pump(t, const UpdateAvailable(_new));
    expect(find.text('Update 0.3.0 available'), findsOneWidget);
    expect(find.text('• Fixture feature'), findsOneWidget);
    await t.tap(find.text('Download and install'));
    expect(ctl.installs, ['0.3.0']);
  });

  testWidgets('FR-31-20 downloading shows progress and cancel', (t) async {
    final ctl = await _pump(t, const UpdateDownloading(_new, 0.42));
    expect(find.text('Downloading 0.3.0... 42%'), findsOneWidget);
    expect(
      t
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('update-progress')),
          )
          .value,
      0.42,
    );
    await t.tap(find.byKey(const Key('cancel-download')));
    expect(ctl.cancels, 1);
  });

  testWidgets('FR-31-20 full progress reads Verifying', (t) async {
    await _pump(t, const UpdateDownloading(_new, 1));
    expect(find.text('Verifying 0.3.0...'), findsOneWidget);
  });

  testWidgets('FR-31-21 hash mismatch: message, retry, release page',
      (t) async {
    final ch = _Channel();
    final ctl = await _pump(
      t,
      const UpdateFailed(checksumMismatchMessage, release: _new),
      ch: ch,
    );
    expect(find.text(checksumMismatchMessage), findsOneWidget);
    await t.tap(find.text('Open release page'));
    await t.pump();
    expect(
        ch.opened.single,
        'https://github.com/DhyanendraSinghSikarwar/'
        'DhanKosh/releases/tag/v0.3.0');
    await t.tap(find.text('Try again'));
    expect(ctl.installs, ['0.3.0']);
  });

  testWidgets('FR-31-22 permission needed shows instruction and Retry',
      (t) async {
    final ctl = await _pump(t, const UpdatePermissionNeeded(_new));
    expect(find.byKey(const Key('update-permission')), findsOneWidget);
    await t.tap(find.text('Retry'));
    expect(ctl.installs, ['0.3.0']);
  });

  testWidgets('FR-31-22 handed off keeps a fallback', (t) async {
    await _pump(t, const UpdateHandedOff(_new));
    expect(find.byKey(const Key('update-handed-off')), findsOneWidget);
    expect(find.text('Open release page'), findsOneWidget);
  });

  testWidgets('FR-31-29 history marks Installed and New, newest first',
      (t) async {
    final ctl = await _pump(
      t,
      const UpdateIdle(),
      h: const HistoryState(releases: [_new, _cur]),
    );
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('0.3.0')).dy < t.getTopLeft(find.text('0.1.0')).dy,
      isTrue,
    );
    await t.ensureVisible(find.byKey(const Key('release-0.3.0')));
    await t.tap(find.byKey(const Key('release-0.3.0')));
    await t.pumpAndSettle();
    expect(find.text('• Fixture feature'), findsOneWidget);
    await t.tap(find.byKey(const Key('install-0.3.0')));
    expect(ctl.installs, ['0.3.0']);
  });

  testWidgets('FR-31-30 offline history shows the cached list and a note',
      (t) async {
    await _pump(
      t,
      const UpdateIdle(),
      h: const HistoryState(releases: [_cur], failed: true),
    );
    expect(find.text('Offline. Showing the last saved list.'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
  });

  testWidgets("FR-31-36 What's new sheet lists the notes", (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => WhatsNewSheet.show(
              c,
              version: '0.3.0',
              points: const ['One', 'Two'],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text("What's new in 0.3.0"), findsOneWidget);
    expect(find.text('• One'), findsOneWidget);
    await t.tap(find.byKey(const Key('whats-new-done')));
    await t.pumpAndSettle();
    expect(find.text("What's new in 0.3.0"), findsNothing);
  });

  group('Home notice dismissal', () {
    late StreamController<String> known;
    late StreamController<String> dismissed;
    late ProviderContainer c;
    setUp(() {
      known = StreamController<String>();
      dismissed = StreamController<String>();
      c = ProviderContainer(
        overrides: [
          knownUpdateProvider.overrideWith((_) => known.stream),
          dismissedUpdateProvider.overrideWith((_) => dismissed.stream),
        ],
      )..listen(homeUpdateVersionProvider, (_, __) {});
    });
    tearDown(() async {
      c.dispose();
      await known.close();
      await dismissed.close();
    });

    Future<String?> notice() {
      return Future<void>.delayed(Duration.zero)
          .then((_) => c.read(homeUpdateVersionProvider));
    }

    test('FR-31-33 shown, dismissed per version, back for a newer one',
        () async {
      known.add('');
      dismissed.add('');
      expect(await notice(), isNull);
      known.add('0.3.0');
      expect(await notice(), '0.3.0');
      dismissed.add('0.3.0');
      expect(await notice(), isNull);
      known.add('0.4.0');
      expect(await notice(), '0.4.0');
    });

    test('FR-31-33 a known version not newer than installed is hidden',
        () async {
      known.add('0.1.0');
      dismissed.add('');
      expect(await notice(), isNull);
    });

    test('FR-31-33 dismiss stores the version', () async {
      final env = TestEnv();
      addTearDown(env.close);
      final c2 = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(env.settings)],
      );
      addTearDown(c2.dispose);
      await c2.read(dismissUpdateNoticeProvider)('0.3.0');
      expect(await env.settings.read(updateNoticeDismissedKey), '0.3.0');
    });
  });
}
