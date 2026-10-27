import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Renders the [RepaintBoundary] under [key] to PNG bytes at [pixelRatio]
/// (3 gives an HD image); null when it is not laid out.
Future<Uint8List?> captureBoundaryPng(
  GlobalKey key, {
  double pixelRatio = 3,
}) async {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderRepaintBoundary) return null;
  final image = await box.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
