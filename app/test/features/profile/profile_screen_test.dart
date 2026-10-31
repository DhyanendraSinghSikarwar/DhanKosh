import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/profile/data/bank_identity_store.dart';
import 'package:hisaab/features/profile/presentation/profile_screen.dart';

import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class _Profile implements ProfileRepository {
  UserProfile value = const UserProfile(name: 'Asha Demo');
  final log = <String>[];
  @override
  Future<UserProfile> read() async => value;
  @override
  Future<void> save(UserProfile profile) async {
    log.add('profile');
    value = profile;
  }
}

class _Identity implements IdentityRepository {
  _Identity(this.log);
  Identity? value = const Identity(name: 'Asha Demo');
  final List<String> log;
  @override
  Future<Identity?> read() async => value;
  @override
  Future<void> save(Identity identity) async {
    log.add('identity');
    value = identity;
  }
}

void main() {
  late TestEnv env;
  late _Profile profile;
  late _Identity identity;
  setUp(() {
    env = TestEnv();
    profile = _Profile();
    identity = _Identity(profile.log);
  });
  tearDown(() => env.close());

  Future<void> pump(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          profileRepositoryProvider.overrideWithValue(profile),
          identityRepositoryProvider.overrideWithValue(identity),
          bankIdentityRepositoryProvider
              .overrideWithValue(BankIdentityStore(MemSecure())),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await settle(t);
  }

  bool saveEnabled(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const Key('profile-save'))).onPressed !=
      null;

  // TC-27-08 (FR-27-07, FR-27-08)
  testWidgets('validation gates Save', (t) async {
    await pump(t);
    expect(find.text('Asha Demo'), findsOneWidget);
    expect(saveEnabled(t), isFalse);
    await t.enterText(find.byKey(const Key('profile-pan')), 'abcd1');
    await t.pump();
    expect(find.text('Format ABCDE1234F'), findsOneWidget);
    expect(saveEnabled(t), isFalse);
    await t.enterText(find.byKey(const Key('profile-pan')), 'abcde1234f');
    await t.pump();
    expect(saveEnabled(t), isTrue);
    await t.enterText(find.byKey(const Key('profile-name')), '');
    await t.pump();
    expect(saveEnabled(t), isFalse);
    await teardownApp(t);
  });

  // TC-27-09 (FR-27-05, FR-27-13)
  testWidgets('save writes identity then profile', (t) async {
    await pump(t);
    await t.enterText(find.byKey(const Key('profile-pan')), 'abcde1234f');
    await t.enterText(find.byKey(const Key('profile-mobile')), '9876543210');
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('profile-save')));
    await t.tap(find.byKey(const Key('profile-save')));
    await t.pump();
    await settle(t);
    expect(profile.log, ['identity', 'profile']);
    expect(identity.value!.pan, 'ABCDE1234F');
    expect(profile.value.phone, '+91 9876543210');
    await teardownApp(t);
  });

  // FR-27-15
  testWidgets('bank details row shows counts', (t) async {
    await pump(t);
    expect(find.text('0 saved  ·  0 statement passwords'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-27-16, FR-27-23
  testWidgets('occupation and several alternate names and mobiles save',
      (t) async {
    await pump(t);
    await t.enterText(find.byKey(const Key('profile-occupation')), 'Engineer');
    await t.enterText(find.byKey(const Key('profile-alt-name')), 'A Demo');
    await t.ensureVisible(find.byKey(const Key('profile-alt-name-add')));
    await t.tap(find.byKey(const Key('profile-alt-name-add')));
    await t.pump();
    await t.enterText(find.byKey(const Key('profile-alt-name')), 'Asha D');
    await t.tap(find.byKey(const Key('profile-alt-name-add')));
    await t.pump();
    await t.enterText(find.byKey(const Key('profile-alt-phone')), '98765');
    await t.tap(find.byKey(const Key('profile-alt-phone-add')));
    await t.pump();
    expect(find.byKey(const Key('alt-phone-+91 98765')), findsNothing);
    await t.enterText(find.byKey(const Key('profile-alt-phone')), '9876543210');
    await t.tap(find.byKey(const Key('profile-alt-phone-add')));
    await t.pump();
    await t.enterText(find.byKey(const Key('profile-alt-phone')), '9123456780');
    await t.tap(find.byKey(const Key('profile-alt-phone-add')));
    await t.pump();
    expect(saveEnabled(t), isTrue);
    await t.ensureVisible(find.byKey(const Key('profile-save')));
    await t.tap(find.byKey(const Key('profile-save')));
    await t.pump();
    await settle(t);
    expect(profile.value.occupation, 'Engineer');
    final id = identity.value!;
    expect(id.altName, 'A Demo');
    expect(id.moreNames, ['Asha D']);
    expect(id.altPhone, '+91 9876543210');
    expect(id.morePhones, ['+91 9123456780']);
    await teardownApp(t);
  });

  testWidgets('a saved alternate can be removed', (t) async {
    identity.value = const Identity(
      name: 'Asha Demo',
      altName: 'A Demo',
      moreNames: ['Asha D'],
    );
    await pump(t);
    expect(find.byKey(const Key('alt-name-Asha D')), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('alt-name-A Demo')));
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('alt-name-A Demo')),
        matching: find.byTooltip('Delete'),
      ),
    );
    await t.pump();
    expect(find.byKey(const Key('alt-name-A Demo')), findsNothing);
    expect(saveEnabled(t), isTrue);
    await teardownApp(t);
  });

  // FR-27-24
  testWidgets('heart opens Support', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
        GoRoute(
          path: '/settings/support',
          builder: (_, __) => const Scaffold(body: Text('support-page')),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          profileRepositoryProvider.overrideWithValue(profile),
          identityRepositoryProvider.overrideWithValue(identity),
          bankIdentityRepositoryProvider
              .overrideWithValue(BankIdentityStore(MemSecure())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(t);
    await t.tap(find.byKey(const Key('profile-support')));
    await t.pumpAndSettle();
    expect(find.text('support-page'), findsOneWidget);
    await teardownApp(t);
  });
}
