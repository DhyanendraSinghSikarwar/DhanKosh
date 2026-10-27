import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/profile/data/profile_photo_store_impl.dart';
import 'package:hisaab/features/profile/domain/profile_photo.dart';
import 'package:hisaab/features/profile/presentation/photo_crop_screen.dart';
import 'package:hisaab/shared/widgets/profile_avatar.dart';

class _Profile implements ProfileRepository {
  UserProfile value = const UserProfile(name: 'Asha Demo', occupation: 'Doc');
  @override
  Future<UserProfile> read() async => value;
  @override
  Future<void> save(UserProfile profile) async => value = profile;
}

class _Store implements ProfilePhotoStore {
  final saved = <Uint8List>[];
  final deleted = <String?>[];
  @override
  Future<String> save(Uint8List png) async {
    saved.add(png);
    return '/p/photo_${saved.length}.png';
  }

  @override
  Future<void> delete(String? path) async => deleted.add(path);
}

Future<Uint8List> _png() async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
    const Rect.fromLTWH(0, 0, 40, 20),
    Paint()..color = Colors.teal,
  );
  final img = await rec.endRecording().toImage(40, 20);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
}

void main() {
  group('SetProfilePhoto (FR-27-09)', () {
    test('saves the new photo, keeps other fields, deletes the old file',
        () async {
      final profile = _Profile();
      final store = _Store();
      final use = SetProfilePhoto(store, profile);
      await use.set(Uint8List.fromList([1]));
      expect(profile.value.photoPath, '/p/photo_1.png');
      expect(profile.value.name, 'Asha Demo');
      expect(profile.value.occupation, 'Doc');
      expect(store.deleted, isEmpty);
      await use.set(Uint8List.fromList([2]));
      expect(profile.value.photoPath, '/p/photo_2.png');
      expect(store.deleted, ['/p/photo_1.png']);
    });

    test('clear removes the path and the file', () async {
      final profile = _Profile();
      final store = _Store();
      final use = SetProfilePhoto(store, profile);
      await use.set(Uint8List.fromList([1]));
      await use.clear();
      expect(profile.value.photoPath, '');
      expect(store.deleted, ['/p/photo_1.png']);
      expect(profile.value.name, 'Asha Demo');
    });
  });

  test('photo file lives in the given private folder and can be deleted',
      () async {
    final dir = await Directory.systemTemp.createTemp('dk_photo');
    addTearDown(() => dir.delete(recursive: true));
    final store = ProfilePhotoStoreImpl(directory: () async => dir);
    final path = await store.save(Uint8List.fromList([9, 9]));
    expect(path.startsWith('${dir.path}/profile/'), isTrue);
    expect(File(path).readAsBytesSync(), [9, 9]);
    await store.delete(path);
    expect(File(path).existsSync(), isFalse);
    await store.delete(path); // missing file is fine
    await store.delete(null);
  });

  testWidgets('avatar shows initials without a photo (FR-27-09)', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: ProfileAvatar(name: 'asha demo', photoPath: '/no/such.png'),
      ),
    );
    expect(find.text('AD'), findsOneWidget);
    expect(ProfileAvatar.initials(null), 'H');
    expect(ProfileAvatar.initials('  '), 'H');
  });

  testWidgets('crop screen rotates and returns a square PNG (FR-27-09)',
      (t) async {
    final bytes = (await t.runAsync(_png))!;
    Uint8List? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await Navigator.of(context).push<Uint8List>(
              MaterialPageRoute(builder: (_) => PhotoCropScreen(bytes: bytes)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('crop-viewer')), findsOneWidget);
    expect(
      t.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
      0,
    );
    await t.tap(find.byKey(const Key('crop-rotate')));
    await t.pump();
    expect(t.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('crop-done')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await t.pumpAndSettle();
    expect(result, isNotNull);
    final codec = await t.runAsync(() => ui.instantiateImageCodec(result!));
    final frame = await t.runAsync(codec!.getNextFrame);
    expect(frame!.image.width, PhotoCropScreen.outputSize);
    expect(frame.image.height, PhotoCropScreen.outputSize);
  });
}
