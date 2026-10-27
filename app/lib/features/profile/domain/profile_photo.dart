import 'dart:typed_data';

import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';

/// Profile photo files in app-private storage (FR-27-10, FR-27-11).
abstract interface class ProfilePhotoStore {
  /// Writes [png] as the photo and returns its path. Each save uses a new
  /// file name so image caches never show the old photo.
  Future<String> save(Uint8List png);

  /// Deletes the file at [path]; a missing file is fine.
  Future<void> delete(String? path);
}

/// Sets or clears the profile photo; the old file is deleted (FR-27-10, FR-27-11).
class SetProfilePhoto {
  /// Creates the use case.
  const SetProfilePhoto(this._store, this._profile);

  final ProfilePhotoStore _store;
  final ProfileRepository _profile;

  /// Saves [png] (already cropped, zoomed and rotated) as the photo.
  Future<void> set(Uint8List png) async {
    final old = await _profile.read();
    final path = await _store.save(png);
    await _profile.save(_with(old, path));
    if (old.photoPath != null && old.photoPath != path) {
      await _store.delete(old.photoPath);
    }
  }

  /// Removes the photo.
  Future<void> clear() async {
    final old = await _profile.read();
    await _profile.save(_with(old, ''));
    await _store.delete(old.photoPath);
  }

  static UserProfile _with(UserProfile p, String path) => UserProfile(
        name: p.name,
        email: p.email,
        phone: p.phone,
        occupation: p.occupation,
        photoPath: path,
      );
}
