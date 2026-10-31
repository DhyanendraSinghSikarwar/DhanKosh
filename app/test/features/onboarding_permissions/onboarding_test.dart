import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/platform_channels/permissions_channel.dart';
import 'package:hisaab/features/onboarding_permissions/data/identity_store.dart';
import 'package:hisaab/features/onboarding_permissions/data/permission_repository_impl.dart';
import 'package:hisaab/features/onboarding_permissions/data/profile_store.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/sms_permission_state.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/onboarding_permissions/domain/usecases/onboarding_usecases.dart';
import 'package:hisaab/features/onboarding_permissions/domain/validators/onboarding_validators.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

class MemKv implements KeyValueStore, SecureStore {
  final map = <String, String>{};
  @override
  Future<String?> getString(String key) async => map[key];
  @override
  Future<void> setString(String key, String value) async => map[key] = value;
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
}

class _Perm implements SmsPermissionRepository {
  _Perm({required this.granted});
  bool granted;
  @override
  Future<SmsPermissionState> read() async =>
      SmsPermissionState(granted: granted);
  @override
  Future<SmsPermissionState> request() => read();
  @override
  Future<void> openAppSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gate rule (TC-01-01)', () {
    bool n(String? name, String? e, String? p, {bool m = false}) =>
        onboardingNeeded(name: name, email: e, phone: p, mailConnected: m);
    expect(n(null, 'a@b.c', null), isTrue);
    expect(n('A', null, null), isTrue);
    expect(n('A', 'a@b.c', null), isFalse);
    expect(n('A', null, '+91 9876543210'), isFalse);
    expect(n('A', null, null, m: true), isFalse);
  });

  test('validators (TC-01-05)', () {
    expect(OnboardingValidators.isValidPanOrBlank('ABCDE1234F'), isTrue);
    expect(OnboardingValidators.isValidPanOrBlank(''), isTrue);
    expect(OnboardingValidators.isValidPanOrBlank('ABCD1234F'), isFalse);
    expect(OnboardingValidators.phoneDigits('+91 98765-432109'), '9876543210');
    expect(OnboardingValidators.phoneDigits('+91 9876543210'), '9876543210');
    expect(OnboardingValidators.phoneDigits('09876543210'), '9876543210');
    expect(OnboardingValidators.phoneDigits('9876543210'), '9876543210');
    expect(OnboardingValidators.formatPhone('9876543210'), '+91 9876543210');
    expect(OnboardingValidators.formatPhone('987654321'), isNull);
  });

  test(
      'finish saves identity before profile; alternates only sealed (TC-01-06)',
      () async {
    final id = _SealedRec();
    final prof = _ProfRec();
    final order = <String>[];
    id.log = order;
    prof.log = order;
    Set<String>? tails;
    final u = FinishOnboarding(
      identity: id,
      profile: prof,
      publishOwnNumbers: (t) async => tails = t,
    );
    await u(
      OnboardingInput(
        name: ' Asha Rao ',
        email: 'asha@example.com',
        phoneDigits: '9876543210',
        dob: DateTime(1990, 5, 14),
        pan: 'abcde1234f',
        altName: 'Asha R',
        altPhoneDigits: '9123456780',
      ),
    );
    expect(order, ['identity', 'profile']);
    expect(id.saved!.pan, 'ABCDE1234F');
    expect(id.saved!.altPhone, '+91 9123456780');
    expect(prof.saved!.name, 'Asha Rao');
    expect(prof.saved!.phone, '+91 9876543210');
    expect(tails, {'3210', '6780'});
  });

  test('skip keeps name/email/mobile only (TC-01-07)', () async {
    final id = _SealedRec();
    await FinishOnboarding(identity: id, profile: _ProfRec()).skip(
      OnboardingInput(
        name: 'Asha',
        phoneDigits: '9876543210',
        pan: 'ABCDE1234F',
        altName: 'x',
        dob: DateTime(1990),
      ),
    );
    expect(id.saved!.pan, isNull);
    expect(id.saved!.dob, isNull);
    expect(id.saved!.altName, isNull);
    expect(id.saved!.phone, '+91 9876543210');
  });

  test('invalid PAN blocks finish', () async {
    expect(
      FinishOnboarding(identity: _SealedRec(), profile: _ProfRec())(
        const OnboardingInput(name: 'A', pan: 'BAD'),
      ),
      throwsArgumentError,
    );
  });

  test('own number tails (TC-01-08)', () {
    expect(ownNumberTails(['+91 98765 43210', '12345678', null]), {'3210'});
  });

  test('identity store round trip, plain profile has no PAN (FR-01-07)',
      () async {
    final kv = MemKv();
    final store = IdentityStore(kv);
    final i = Identity(
      name: 'Asha Rao',
      dob: DateTime(1990, 5, 14),
      pan: 'ABCDE1234F',
      altName: 'Asha R',
    );
    await store.save(i);
    final back = (await store.read())!;
    expect(back.dob, DateTime(1990, 5, 14));
    expect(back.pan, 'ABCDE1234F');
    final plain = MemKv();
    await ProfileStore(plain)
        .save(const UserProfile(name: 'Asha', phone: '+91 9876543210'));
    expect(plain.map.values.join(), isNot(contains('ABCDE')));
    expect((await ProfileStore(plain).read()).name, 'Asha');
  });

  test('watcher fires once per false->true edge (TC-01-09)', () async {
    final perm = _Perm(granted: false);
    var fired = 0;
    final w =
        SmsPermissionWatcher(repository: perm, onGranted: () async => fired++);
    await w.refresh();
    await w.refresh();
    expect(fired, 0);
    perm.granted = true;
    await w.refresh();
    await w.refresh();
    expect(fired, 1);
    perm.granted = false;
    await w.refresh();
    perm.granted = true;
    await w.refresh();
    expect(fired, 2);
  });

  test('already granted at start does not fire', () async {
    var fired = 0;
    await SmsPermissionWatcher(
      repository: _Perm(granted: true),
      onGranted: () async => fired++,
    ).refresh();
    expect(fired, 0);
  });

  test('notifications asked once, flag set before request (TC-01-12)',
      () async {
    final kv = MemKv();
    final seenFlag = <String?>[];
    final ask = AskNotificationsOnce(
      kv,
      _Notif(() => seenFlag.add(kv.map['notifications_asked'])),
    );
    expect(await ask(), isTrue);
    expect(await ask(), isFalse);
    expect(seenFlag, ['true']);
  });

  group('permission repository (TC-01-10)', () {
    const channel = PermissionsChannel();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel.channel, null));

    test('refusal without rationale marks blocked; next request opens settings',
        () async {
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel.channel, (call) async {
        methods.add(call.method);
        return call.method == 'smsStatus'
            ? {'granted': false, 'rationale': false}
            : null;
      });
      var locked = 0;
      final repo = SmsPermissionRepositoryImpl(
        channel,
        beforeOpenSettings: () async => locked++,
      );
      final first = await repo.request();
      expect(first.blocked, isTrue);
      expect(methods, contains('requestSms'));
      methods.clear();
      await repo.request();
      expect(methods, isNot(contains('requestSms')));
      expect(methods, contains('openAppSettings'));
      expect(locked, 1);
    });

    test('trusts real state when granted', () async {
      messenger.setMockMethodCallHandler(
        channel.channel,
        (call) async => call.method == 'smsStatus'
            ? {'granted': true, 'rationale': false}
            : null,
      );
      final s = await SmsPermissionRepositoryImpl(channel).request();
      expect([s.granted, s.blocked], [true, false]);
    });
  });
}

class _SealedRec implements IdentityRepository {
  List<String>? log;
  Identity? saved;
  @override
  Future<Identity?> read() async => saved;
  @override
  Future<void> save(Identity identity) async {
    log?.add('identity');
    saved = identity;
  }
}

class _ProfRec implements ProfileRepository {
  List<String>? log;
  UserProfile? saved;
  @override
  Future<UserProfile> read() async => saved ?? const UserProfile();
  @override
  Future<void> save(UserProfile profile) async {
    log?.add('profile');
    saved = profile;
  }
}

class _Notif implements NotificationPermission {
  _Notif(this.onRequest);
  final void Function() onRequest;
  @override
  Future<void> request() async => onRequest();
}
