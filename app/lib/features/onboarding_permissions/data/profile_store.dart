import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

/// [ProfileRepository] over the settings key-value store. Never holds PAN,
/// DOB or alternates (FR-01-07). Name is written last: it ends the gate.
class ProfileStore implements ProfileRepository {
  /// Creates the store.
  const ProfileStore(this._kv);

  final KeyValueStore _kv;

  static const _name = 'display_name';
  static const _email = 'profile_email';
  static const _phone = 'profile_phone';
  static const _occupation = 'profile_occupation';
  static const _photo = 'profile_photo';

  @override
  Future<UserProfile> read() async => UserProfile(
        name: await _kv.getString(_name),
        email: await _kv.getString(_email),
        phone: await _kv.getString(_phone),
        occupation: await _kv.getString(_occupation),
        photoPath: await _kv.getString(_photo),
      );

  @override
  Future<void> save(UserProfile p) async {
    Future<void> put(String k, String? v) async {
      if (v != null) await _kv.setString(k, v);
    }

    await put(_email, p.email);
    await put(_phone, p.phone);
    await put(_occupation, p.occupation);
    await put(_photo, p.photoPath);
    await put(_name, p.name);
  }
}
