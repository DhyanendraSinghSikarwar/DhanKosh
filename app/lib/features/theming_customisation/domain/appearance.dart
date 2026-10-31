import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Theme mode choice (FR-28-01).
enum ThemeModeChoice {
  /// Follow the phone.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Palette groups on the Customise screen (FR-28-13).
enum PaletteGroup {
  /// First 10.
  classic('Classic'),

  /// MIDNIGHT to VIBRANIUM.
  hero('Hero'),

  /// IRON_THRONE to SPICE_DUNE.
  cinema('Cinema');

  const PaletteGroup(this.label);

  /// Display label.
  final String label;
}

/// The 23 palettes in Kotlin enum order (FR-28-02). Index matches the
/// palette registry in `app/theme/palettes.dart`.
enum PaletteId {
  mint('DhanKosh Mint', PaletteGroup.classic),
  dhankosh('DhanKosh', PaletteGroup.classic),
  fold('Fold', PaletteGroup.classic),
  classic('Classic', PaletteGroup.classic),
  emerald('Emerald', PaletteGroup.classic),
  graphite('Graphite', PaletteGroup.classic),
  indigo('Indigo Night', PaletteGroup.classic),
  saffron('Saffron', PaletteGroup.classic),
  ocean('Ocean', PaletteGroup.classic),
  roseQuartz('Rose Quartz', PaletteGroup.classic),
  lavenderBloom('Lavender Bloom', PaletteGroup.classic),
  midnight('Midnight Knight', PaletteGroup.hero),
  arcRed('Arc Red', PaletteGroup.hero),
  starShield('Star Shield', PaletteGroup.hero),
  thunder('Thunder', PaletteGroup.hero),
  gamma('Gamma', PaletteGroup.hero),
  vibranium('Vibranium', PaletteGroup.hero),
  ironThrone('Iron Throne', PaletteGroup.cinema),
  middleRealm('Middle Realm', PaletteGroup.cinema),
  nitro('Nitro', PaletteGroup.cinema),
  neoMatrix('Neo Matrix', PaletteGroup.cinema),
  interstellarDust('Interstellar Dust', PaletteGroup.cinema),
  spiceDune('Spice Dune', PaletteGroup.cinema);

  const PaletteId(this.label, this.group);

  /// Display name.
  final String label;

  /// Customise group.
  final PaletteGroup group;

  /// Palette by stored name; Mint when unknown.
  static PaletteId parse(String? name) => values.firstWhere(
        (p) => p.name == name,
        orElse: () => PaletteId.mint,
      );
}

/// Text size steps (FR-28-09).
enum TextSize {
  small('Small', 0.9),
  standard('Default', 1),
  large('Large', 1.1),
  xl('XL', 1.2);

  const TextSize(this.label, this.factor);

  /// Display label.
  final String label;

  /// Scale factor.
  final double factor;

  /// Nearest step within 0.05, else [standard].
  static TextSize of(double value) {
    for (final s in values) {
      if ((s.factor - value).abs() <= 0.05 + 1e-9) return s;
    }
    return standard;
  }
}

/// Effective text scale = `system * factor`; for `factor > 1` capped at
/// `max(1.3, system)` (FR-28-09).
double effectiveTextScale(double system, double factor) {
  final raw = system * factor;
  if (factor <= 1) return raw;
  final cap = system > 1.3 ? system : 1.3;
  return raw > cap ? cap : raw;
}

/// Appearance settings (FR-28-03 defaults).
class AppearanceSettings {
  /// Creates settings.
  const AppearanceSettings({
    this.mode = ThemeModeChoice.system,
    this.palette = PaletteId.mint,
    this.pureBlack = false,
    this.textSize = TextSize.standard,
    this.reduceMotion = false,
  });

  /// Mode.
  final ThemeModeChoice mode;

  /// Palette.
  final PaletteId palette;

  /// Pure black in dark mode.
  final bool pureBlack;

  /// Text size.
  final TextSize textSize;

  /// Skip decorative motion even when the phone allows it (FR-28-10).
  final bool reduceMotion;

  /// Copy with changes.
  AppearanceSettings copyWith({
    ThemeModeChoice? mode,
    PaletteId? palette,
    bool? pureBlack,
    TextSize? textSize,
    bool? reduceMotion,
  }) =>
      AppearanceSettings(
        mode: mode ?? this.mode,
        palette: palette ?? this.palette,
        pureBlack: pureBlack ?? this.pureBlack,
        textSize: textSize ?? this.textSize,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
}

/// Persisted keys (FR-28-21); text scale stored as whole percent.
abstract final class AppearanceKeys {
  static const mode = SettingKey<String>('theme', 'system');
  static const palette = SettingKey<String>('theme_palette', 'mint');
  static const pureBlack = SettingKey<bool>('pure_black', false);
  static const textScalePct = SettingKey<int>('text_scale_pct', 100);
  static const reduceMotion = SettingKey<bool>('reduce_motion', false);
}

/// Appearance persistence port.
abstract interface class AppearanceRepository {
  /// Emits on every change (defaults first).
  Stream<AppearanceSettings> watch();

  /// Persists [s].
  Future<void> save(AppearanceSettings s);
}
