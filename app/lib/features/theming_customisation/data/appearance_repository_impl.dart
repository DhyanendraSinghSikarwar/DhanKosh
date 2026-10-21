import 'dart:async';

import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';

/// [AppearanceRepository] over the settings store (FR-28-12, FR-28-21).
class AppearanceRepositoryImpl implements AppearanceRepository {
  /// Creates the repository.
  AppearanceRepositoryImpl(this._store);

  final SettingsRepository _store;

  @override
  Stream<AppearanceSettings> watch() {
    late StreamController<AppearanceSettings> c;
    final subs = <StreamSubscription<Object?>>[];
    var cur = const AppearanceSettings();
    void emit(AppearanceSettings s) {
      cur = s;
      if (!c.isClosed) c.add(s);
    }

    c = StreamController<AppearanceSettings>(
      onListen: () {
        emit(cur);
        subs
          ..add(
            _store.watch(AppearanceKeys.mode).listen(
                  (v) => emit(
                    cur.copyWith(
                      mode: ThemeModeChoice.values.firstWhere(
                        (m) => m.name == v,
                        orElse: () => ThemeModeChoice.system,
                      ),
                    ),
                  ),
                ),
          )
          ..add(
            _store.watch(AppearanceKeys.palette).listen(
                  (v) => emit(cur.copyWith(palette: PaletteId.parse(v))),
                ),
          )
          ..add(
            _store.watch(AppearanceKeys.pureBlack).listen(
                  (v) => emit(cur.copyWith(pureBlack: v)),
                ),
          )
          ..add(
            _store.watch(AppearanceKeys.textScalePct).listen(
                  (v) => emit(cur.copyWith(textSize: TextSize.of(v / 100))),
                ),
          );
      },
      onCancel: () => Future.wait(subs.map((s) => s.cancel())),
    );
    return c.stream;
  }

  @override
  Future<void> save(AppearanceSettings s) async {
    await _store.write(AppearanceKeys.mode, s.mode.name);
    await _store.write(AppearanceKeys.palette, s.palette.name);
    await _store.write(AppearanceKeys.pureBlack, s.pureBlack);
    await _store.write(
      AppearanceKeys.textScalePct,
      (s.textSize.factor * 100).round(),
    );
  }
}
