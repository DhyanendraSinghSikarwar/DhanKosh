import 'package:flutter/widgets.dart';

/// Sizes charts to the phone they are on (FR-37-13): a design size is scaled
/// by the screen width (a 390 dp phone keeps it as drawn, narrow and wide
/// phones shrink or grow it a little) and a chart never takes more than a
/// third of the screen's height, so landscape and small screens still fit.
abstract final class ChartSizing {
  /// The width the design sizes were drawn for.
  static const designWidth = 390.0;

  /// Scale for a screen [width]: 0.8 to 1.4 of the design.
  static double scaleFor(double width) => (width / designWidth).clamp(0.8, 1.4);

  /// A chart height of [design] dp on this screen.
  static double height(BuildContext context, double design) {
    final size = MediaQuery.sizeOf(context);
    final h = design * scaleFor(size.width);
    final cap = size.height * 0.33;
    return h > cap ? cap : h;
  }

  /// A square chart (donut) of [design] dp on this screen: scaled like a
  /// height and never wider than 45 per cent of the screen, so its legend
  /// keeps room beside it.
  static double square(BuildContext context, double design) {
    final size = MediaQuery.sizeOf(context);
    final side = height(context, design);
    final cap = size.width * 0.45;
    return side > cap ? cap : side;
  }
}
