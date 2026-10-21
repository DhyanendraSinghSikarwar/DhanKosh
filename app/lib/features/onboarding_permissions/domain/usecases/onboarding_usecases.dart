import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/sms_permission_state.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/onboarding_permissions/domain/validators/onboarding_validators.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

/// Whether Welcome must show (FR-01-01).
bool onboardingNeeded({
  required String? name,
  required String? email,
  required String? phone,
  required bool mailConnected,
}) =>
    name == null || (email == null && phone == null && !mailConnected);

/// Last four digits of every own number with 10+ digits (FR-01-08).
Set<String> ownNumberTails(Iterable<String?> numbers) => {
      for (final n in numbers)
        if (n != null)
          if (n.replaceAll(RegExp(r'\D'), '') case final d when d.length >= 10)
            d.substring(d.length - 4),
    };

/// Input to [FinishOnboarding].
class OnboardingInput {
  /// Creates the input; raw digits are normalised by the use case.
  const OnboardingInput({
    required this.name,
    this.email,
    this.phoneDigits = '',
    this.dob,
    this.pan = '',
    this.altName = '',
    this.altPhoneDigits = '',
  });

  /// Required full name.
  final String name;

  /// Verified email.
  final String? email;

  /// Own mobile digits.
  final String phoneDigits;

  /// Date of birth.
  final DateTime? dob;

  /// PAN, blank allowed.
  final String pan;

  /// Alternate name.
  final String altName;

  /// Alternate phone digits.
  final String altPhoneDigits;
}

/// Saves identity first, profile second (FR-01-06, FR-01-07, FR-01-08).
class FinishOnboarding {
  /// Creates the use case. [publishOwnNumbers] feeds the ledger guard.
  const FinishOnboarding({
    required IdentityRepository identity,
    required ProfileRepository profile,
    Future<void> Function(Set<String> tails)? publishOwnNumbers,
  })  : _identity = identity,
        _profile = profile,
        _publish = publishOwnNumbers;

  final IdentityRepository _identity;
  final ProfileRepository _profile;
  final Future<void> Function(Set<String>)? _publish;

  String? _nz(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Full save. Throws [ArgumentError] on an invalid PAN.
  Future<void> call(OnboardingInput i) => _save(i, skip: false);

  /// Skip: only name, email and mobile are kept.
  Future<void> skip(OnboardingInput i) => _save(i, skip: true);

  Future<void> _save(OnboardingInput i, {required bool skip}) async {
    if (!skip && !OnboardingValidators.isValidPanOrBlank(i.pan)) {
      throw ArgumentError.value(i.pan, 'pan', 'invalid');
    }
    final name = i.name.trim();
    final phone = OnboardingValidators.formatPhone(i.phoneDigits);
    final email = _nz(i.email);
    final pan = skip ? null : _nz(i.pan.toUpperCase());
    final altName = skip ? null : _nz(i.altName);
    final altPhone =
        skip ? null : OnboardingValidators.formatPhone(i.altPhoneDigits);
    await _identity.save(
      Identity(
        name: name,
        dob: skip ? null : i.dob,
        pan: pan,
        phone: phone,
        altName: altName,
        altPhone: altPhone,
        email: email,
      ),
    );
    await _profile.save(UserProfile(name: name, email: email, phone: phone));
    await _publish?.call(ownNumberTails([phone, altPhone]));
  }
}

/// Fires once per missing-to-granted transition (FR-01-09, FR-01-12).
class SmsPermissionWatcher {
  /// Creates the watcher; [onGranted] should enqueue one full scan.
  SmsPermissionWatcher({
    required SmsPermissionRepository repository,
    required Future<void> Function() onGranted,
  })  : _repo = repository,
        _onGranted = onGranted;

  final SmsPermissionRepository _repo;
  final Future<void> Function() _onGranted;
  bool? _last;

  /// Re-reads the real state; call on start and on every app resume.
  Future<SmsPermissionState> refresh() async {
    final s = await _repo.read();
    final was = _last;
    _last = s.granted;
    if (was == false && s.granted) await _onGranted();
    return s;
  }

  /// Requests, then refreshes (the dialog result is ignored).
  Future<SmsPermissionState> request() async {
    await _repo.request();
    return await refresh();
  }
}

/// Asks POST_NOTIFICATIONS once per install (FR-01-14).
class AskNotificationsOnce {
  /// Creates the use case.
  const AskNotificationsOnce(this._flags, this._permission);

  final KeyValueStore _flags;
  final NotificationPermission _permission;

  static const _key = 'notifications_asked';

  /// True when the request was launched on this call.
  Future<bool> call() async {
    if (await _flags.getString(_key) == 'true') return false;
    await _flags.setString(_key, 'true'); // set before launching
    await _permission.request();
    return true;
  }
}
