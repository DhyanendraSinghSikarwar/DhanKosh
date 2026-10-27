import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Crop, zoom and rotate a picked photo into a square avatar (FR-27-09).
/// Pops with PNG bytes, or null when cancelled.
class PhotoCropScreen extends StatefulWidget {
  /// Creates the screen for the picked image [bytes].
  const PhotoCropScreen({required this.bytes, super.key});

  /// Encoded image picked by the user.
  final Uint8List bytes;

  /// Side of the saved square, in pixels.
  static const outputSize = 512;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final GlobalKey _boundary = GlobalKey();
  int _turns = 0;
  bool _saving = false;

  Future<void> _done(double side) async {
    setState(() => _saving = true);
    final b =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(
      pixelRatio: PhotoCropScreen.outputSize / side,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.of(context).pop(data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust photo')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final side = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight)
                .clamp(120.0, 420.0);
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: ClipRect(
                        child: RepaintBoundary(
                          key: _boundary,
                          child: ColoredBox(
                            color: Colors.black,
                            child: InteractiveViewer(
                              key: const Key('crop-viewer'),
                              minScale: 1,
                              maxScale: 6,
                              boundaryMargin: EdgeInsets.all(side),
                              child: RotatedBox(
                                quarterTurns: _turns,
                                child: Image.memory(
                                  widget.bytes,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        key: const Key('crop-rotate'),
                        tooltip: 'Rotate',
                        icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                        onPressed: () =>
                            setState(() => _turns = (_turns + 1) % 4),
                      ),
                      const Text('Pinch to zoom, drag to move'),
                      FilledButton(
                        key: const Key('crop-done'),
                        onPressed: _saving ? null : () => _done(side),
                        child: const Text('Use photo'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
