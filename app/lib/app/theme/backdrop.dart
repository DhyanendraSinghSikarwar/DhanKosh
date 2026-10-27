import 'package:flutter/material.dart';

/// Backdrop colours of the active palette and mode (FR-28-08), carried in the
/// theme so each page can paint its own backdrop.
@immutable
class BackdropTheme extends ThemeExtension<BackdropTheme> {
  /// Creates the extension. [glowStrength] is the palette's strength; light
  /// mode applies its own 0.62 factor.
  const BackdropTheme({
    required this.base,
    required this.bottom,
    required this.glows,
    required this.dark,
    this.glowStrength = 1,
  });

  /// Calm base colour (the scheme surface).
  final Color base;

  /// Colour the wash ends in.
  final Color bottom;

  /// Three glow colours.
  final List<Color> glows;

  /// Dark mode.
  final bool dark;

  /// Palette glow strength (FOLD 0.25).
  final double glowStrength;

  /// `k = (dark ? 1 : 0.62) x glowStrength` (FR-28-08).
  double get k => (dark ? 1.0 : 0.62) * glowStrength;

  /// Glow alphas `0.16k, 0.13k, 0.09k`.
  List<double> get alphas =>
      backdropAlphas(dark: dark, glowStrength: glowStrength);

  @override
  BackdropTheme copyWith({
    Color? base,
    Color? bottom,
    List<Color>? glows,
    bool? dark,
    double? glowStrength,
  }) =>
      BackdropTheme(
        base: base ?? this.base,
        bottom: bottom ?? this.bottom,
        glows: glows ?? this.glows,
        dark: dark ?? this.dark,
        glowStrength: glowStrength ?? this.glowStrength,
      );

  @override
  BackdropTheme lerp(ThemeExtension<BackdropTheme>? other, double t) =>
      other is BackdropTheme ? (t < 0.5 ? this : other) : this;
}

/// Glow alphas `0.16k, 0.13k, 0.09k` with `k = (dark ? 1 : 0.62) x strength`.
List<double> backdropAlphas({
  required bool dark,
  required double glowStrength,
}) {
  final k = (dark ? 1.0 : 0.62) * glowStrength;
  return [0.16 * k, 0.13 * k, 0.09 * k];
}

/// Vertical wash from the base (to 35% of the height) into the bottom colour,
/// plus three radial glows at (5%, 30%), (100%, 55%) and (20%, 98%).
class BackdropPainter extends CustomPainter {
  /// Creates the painter.
  const BackdropPainter(this.theme);

  /// Colours and strength.
  final BackdropTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.base, theme.base, theme.bottom],
          stops: const [0, 0.35, 1],
        ).createShader(rect),
    );
    final a = theme.alphas;
    final spots = [
      (Offset(w * 0.05, h * 0.30), w * 0.85),
      (Offset(w, h * 0.55), w * 0.80),
      (Offset(w * 0.20, h * 0.98), w * 0.90),
    ];
    for (var i = 0; i < 3; i++) {
      final (center, radius) = spots[i];
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              theme.glows[i].withValues(alpha: a[i]),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(BackdropPainter old) => old.theme != theme;
}

/// Paints the backdrop behind [child] when the theme has one.
class Backdrop extends StatelessWidget {
  /// Creates the backdrop.
  const Backdrop({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BackdropTheme>();
    if (t == null) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('backdrop'),
              painter: BackdropPainter(t),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Page transition that paints the backdrop under every page (so transparent
/// scaffolds overlap cleanly) and skips motion when animations are off or
/// reduced (FR-28-08, FR-28-10).
class BackdropPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates the builder.
  const BackdropPageTransitionsBuilder();

  static const _inner = ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = Backdrop(child: child);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return page;
    return _inner.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      page,
    );
  }
}
