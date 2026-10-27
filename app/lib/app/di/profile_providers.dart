import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/profile/data/profile_photo_store_impl.dart';
import 'package:hisaab/features/profile/domain/profile_photo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_providers.g.dart';

/// Photo files in app-private storage; override in tests.
@Riverpod(keepAlive: true)
ProfilePhotoStore profilePhotoStore(Ref ref) => ProfilePhotoStoreImpl();

/// Set or clear the profile photo (FR-27-10).
@Riverpod(keepAlive: true)
SetProfilePhoto setProfilePhoto(Ref ref) => SetProfilePhoto(
      ref.watch(profilePhotoStoreProvider),
      ref.watch(profileRepositoryProvider),
    );
