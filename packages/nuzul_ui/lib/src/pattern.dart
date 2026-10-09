import 'package:flutter/material.dart';

import 'generated/tokens.dart';

/// The house-lattice pattern (v3 `Pattern`): the logo's hexagon repeated like a honeycomb, a four-point star
/// in the middle of half the cells. Use it as a quiet ground behind content, never behind small text.
///
/// Ported from `nuzuln-pattern-tile-*.svg` (tile 120 x 224): the lines and stars are the same polygons.
enum NzPatternTone {
  /// Night ground with `night-line` lattice: login, splash, heroes.
  night(NzBrand.night, NzBrand.nightLine, Color(0xFF2C5649)),

  /// Mist ground for quiet bands in the light theme.
  mist(NzBrand.mist, Color(0xFFDCE3DD), Color(0xFFC9D3CC));

  const NzPatternTone(this.ground, this.line, this.star);

  final Color ground;
  final Color line;
  final Color star;
}

class NzPattern extends StatelessWidget {
  const NzPattern({super.key, this.tone = NzPatternTone.night, this.scale = 1, this.child});

  final NzPatternTone tone;

  /// 1 draws the 120px tile at its natural size.
  final double scale;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _PatternPainter(tone, scale),
        child: child,
      );
}

const double _tileW = 120;
const double _tileH = 224;

/// Hexagon centres on the tile grid (the SVG draws ten hexagons so the tile joins seamlessly).
const List<List<double>> _centres = [
  [0, 0], [60, 112], [120, 0], [0, 224], [120, 224], [-60, 112], [60, -112], [60, 336], [-60, -112], [180, 112],
];

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.tone, this.scale);

  final NzPatternTone tone;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = tone.ground);
    canvas.clipRect(Offset.zero & size);
    final line = Paint()
      ..color = tone.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.miter;
    final star = Paint()..color = tone.star;

    final hex = Path()
      ..moveTo(0, -77)
      ..lineTo(60, -35)
      ..lineTo(60, 35)
      ..lineTo(0, 77)
      ..lineTo(-60, 35)
      ..lineTo(-60, -35)
      ..close();
    final tileStar = Path()
      ..moveTo(60, 101)
      ..lineTo(63.5, 108.5)
      ..lineTo(71, 112)
      ..lineTo(63.5, 115.5)
      ..lineTo(60, 123)
      ..lineTo(56.5, 115.5)
      ..lineTo(49, 112)
      ..lineTo(56.5, 108.5)
      ..close();
    final cornerStar = Path()
      ..moveTo(0, -5)
      ..lineTo(1.6, -1.6)
      ..lineTo(5, 0)
      ..lineTo(1.6, 1.6)
      ..lineTo(0, 5)
      ..lineTo(-1.6, 1.6)
      ..lineTo(-5, 0)
      ..lineTo(-1.6, -1.6)
      ..close();

    final w = _tileW * scale;
    final h = _tileH * scale;
    for (var ty = -1; ty * h < size.height; ty++) {
      for (var tx = -1; tx * w < size.width; tx++) {
        canvas.save();
        canvas.translate(tx * w, ty * h);
        canvas.scale(scale);
        for (final c in _centres) {
          canvas.drawPath(hex.shift(Offset(c[0], c[1])), line);
        }
        canvas.drawPath(tileStar, star);
        canvas.drawPath(cornerStar, star);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.tone != tone || old.scale != scale;
}
