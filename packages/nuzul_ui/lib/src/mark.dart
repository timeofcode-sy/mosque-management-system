import 'package:flutter/material.dart';

part 'generated/mark_data.dart';

/// The v3 mark (the word نزلاً as a house) in one or two inks.
///
/// Defaults follow the theme: ribbons in `primary` (deep green in light, bronze at night) and the crescent
/// and stars in `onSurface`. On the brand ground pass `ribbons: NzBrand.bronze, lights: NzBrand.star`.
class NzMark extends StatelessWidget {
  const NzMark({super.key, this.height = 48, this.ribbons, this.lights, this.semanticLabel = 'نزلاً'});

  final double height;
  final Color? ribbons;
  final Color? lights;
  final String? semanticLabel;

  /// Width of the mark for a given height.
  static double widthFor(double height) => height * _markW / _markH;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paint = CustomPaint(
      size: Size(widthFor(height), height),
      painter: _NzMarkPainter(ribbons ?? scheme.primary, lights ?? scheme.onSurface),
    );
    final label = semanticLabel;
    return label == null ? ExcludeSemantics(child: paint) : Semantics(label: label, image: true, child: paint);
  }
}

class _NzMarkPainter extends CustomPainter {
  _NzMarkPainter(this.ribbons, this.lights);

  final Color ribbons;
  final Color lights;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.height / _markH);
    final r = Paint()..color = ribbons;
    for (final poly in _ribbons) {
      final p = Path()..moveTo(poly[0], poly[1]);
      for (var i = 2; i < poly.length; i += 2) {
        p.lineTo(poly[i], poly[i + 1]);
      }
      canvas.drawPath(p..close(), r);
    }
    final l = Paint()..color = lights;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset(_moonOuter[0], _moonOuter[1]), radius: _moonOuter[2])),
      Path()..addOval(Rect.fromCircle(center: Offset(_moonInner[0], _moonInner[1]), radius: _moonInner[2])),
    );
    canvas.drawPath(moon, l);
    for (var s = 0; s < _starSegs.length; s += 4) {
      final star = Path()..moveTo(_starSegs[s][0], _starSegs[s][1]);
      for (var k = s; k < s + 4; k++) {
        final g = _starSegs[k];
        star.cubicTo(g[2], g[3], g[4], g[5], g[6], g[7]);
      }
      canvas.drawPath(star..close(), l);
    }
  }

  @override
  bool shouldRepaint(_NzMarkPainter old) => old.ribbons != ribbons || old.lights != lights;
}
