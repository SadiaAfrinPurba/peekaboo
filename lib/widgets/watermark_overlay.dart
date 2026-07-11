import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A faint, full-coverage diagonal watermark that skips detected subject
/// regions ([clearRects], in the painter's own coordinate space).
///
/// Everywhere else the mark is tiled so it can't be cropped out; over faces it
/// is omitted so the subject reads perfectly. (Trade-off the owner chose: a
/// tight crop of the face is unwatermarked.)
class WatermarkOverlay extends StatelessWidget {
  final String label;
  final double opacity;
  final List<Rect> clearRects;

  const WatermarkOverlay({
    super.key,
    required this.label,
    this.opacity = 0.10,
    this.clearRects = const [],
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _WatermarkPainter('$label · Peekaboo', opacity, clearRects),
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;
  final double opacity;
  final List<Rect> clearRects;
  _WatermarkPainter(this.text, this.opacity, this.clearRects);

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withOpacity(opacity),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double stepX = tp.width + 70;
    final double stepY = tp.height + 90;
    const double angle = -30 * math.pi / 180;

    int row = 0;
    for (double y = 0; y < size.height + stepY; y += stepY, row++) {
      final rowOffset = row.isEven ? 0.0 : stepX / 2;
      for (double x = -tp.width; x < size.width + stepX; x += stepX) {
        final px = x + rowOffset;
        // Skip this tile if its center falls inside a subject region.
        final center = Offset(px + tp.width / 2, y + tp.height / 2);
        if (_isClear(center)) continue;

        canvas.save();
        canvas.translate(px, y);
        canvas.rotate(angle);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  bool _isClear(Offset p) {
    for (final r in clearRects) {
      if (r.contains(p)) return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter old) =>
      old.text != text ||
      old.opacity != opacity ||
      old.clearRects != clearRects;
}
