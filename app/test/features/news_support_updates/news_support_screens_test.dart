import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/core/platform_channels/widget_channel.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';
import 'package:hisaab/features/news_support_updates/presentation/support_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/updates_screen.dart';

class _Channel extends WidgetChannel {
  _Channel({this.ok = true});
  final bool ok;
  final opened = <String>[];

  @override
  Future<bool> openUrl(
    String url, {
    bool chooser = false,
    String chooserTitle = 'Open with',
  }) async {
    opened.add(url);
    return ok;
  }
}

class _Fixed extends UpdateController {
  _Fixed(this.initial);
  final UpdateState initial;

  @override
  UpdateState build() => initial;
}

Widget _app(Widget child, _Channel ch, {UpdateState? update}) => ProviderScope(
      overrides: [
        widgetChannelProvider.overrideWithValue(ch),
        if (update != null)
          updateControllerProvider.overrideWith(() => _Fixed(update)),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('FR-31-11/12 support pills build the UPI link', (t) async {
    final ch = _Channel();
    await t.pumpWidget(_app(const SupportScreen(upiId: 'dummy@upi'), ch));
    expect(find.text('₹100'), findsOneWidget);
    expect(find.text('dummy@upi'), findsNothing); // FR-31-13: never shown
    await t.tap(find.byKey(const Key('support-pill-200')));
    await t.pump();
    await t.tap(find.byKey(const Key('support-pay')));
    await t.pump();
    expect(
      ch.opened.single,
      'upi://pay?pa=dummy@upi&pn=DhanKosh&cu=INR&am=200',
    );
  });

  testWidgets('custom amount is digits only and max 6', (t) async {
    final ch = _Channel();
    await t.pumpWidget(_app(const SupportScreen(upiId: 'dummy@upi'), ch));
    await t.tap(find.byKey(const Key('support-pill-custom')));
    await t.pump();
    await t.enterText(
      find.byKey(const Key('support-custom-field')),
      '12ab34567',
    );
    await t.pump();
    await t.tap(find.byKey(const Key('support-pay')));
    await t.pump();
    expect(ch.opened.single, endsWith('&am=123456'));
  });

  testWidgets('no UPI app shows a message', (t) async {
    final ch = _Channel(ok: false);
    await t.pumpWidget(_app(const SupportScreen(upiId: 'dummy@upi'), ch));
    await t.tap(find.byKey(const Key('support-pay')));
    await t.pump();
    expect(find.text('No UPI app found'), findsOneWidget);
  });

  testWidgets('About shows version, licence and privacy statement', (t) async {
    await t.pumpWidget(_app(const UpdatesScreen(), _Channel()));
    expect(find.text('Version 0.1.0'), findsOneWidget);
    expect(find.byKey(const Key('about-privacy')), findsOneWidget);
    expect(find.byKey(const Key('about-licence')), findsOneWidget);
    expect(find.text('Not checked yet.'), findsOneWidget);
  });

  testWidgets('FR-31-22 available update hands the APK URL over', (t) async {
    final ch = _Channel();
    const r = Release(
      version: '0.2.0',
      notes: '- Spend widget',
      apkUrl: 'https://example.test/a.apk',
    );
    await t.pumpWidget(
      _app(
        const UpdatesScreen(),
        ch,
        update: const UpdateAvailable(r),
      ),
    );
    expect(find.text('DhanKosh 0.2.0 is available'), findsOneWidget);
    expect(find.text('• Spend widget'), findsOneWidget);
    await t.tap(find.byKey(const Key('install-update')));
    await t.pump();
    expect(ch.opened.single, 'https://example.test/a.apk');
  });
}
