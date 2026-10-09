import 'package:flutter/widgets.dart';

part 'generated/icon_data.dart';
part 'generated/icon_extra.dart';
part 'generated/icon_names.dart';

class _NzStroke {
  const _NzStroke(this.points, {required this.closed, required this.filled});

  /// x, y pairs on the 24 grid.
  final List<double> points;
  final bool closed;
  final bool filled;
}

const Map<String, List<_NzStroke>> _nzIconAll = {..._nzIconData, ..._nzIconExtra};

/// One icon of the Nuzulan set, drawn in the ambient [IconTheme] colour unless [color] is given.
class NzIcon extends StatelessWidget {
  const NzIcon(this.name, {super.key, this.size, this.color, this.semanticLabel});

  final String name;
  final double? size;
  final Color? color;

  /// Accessible name; leave null for decorative icons next to a text label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? const Color(0xFF0A241F);
    final strokes = _nzIconAll[name];
    assert(strokes != null, 'Unknown Nuzulan icon "$name"');
    final paint = CustomPaint(size: Size.square(s), painter: _NzIconPainter(strokes ?? const [], c));
    final label = semanticLabel;
    return label == null ? ExcludeSemantics(child: paint) : Semantics(label: label, image: true, child: paint);
  }
}

class _NzIconPainter extends CustomPainter {
  _NzIconPainter(this.strokes, this.color);

  final List<_NzStroke> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final s in strokes) {
      final p = Path()..moveTo(s.points[0], s.points[1]);
      for (var i = 2; i < s.points.length; i += 2) {
        p.lineTo(s.points[i], s.points[i + 1]);
      }
      if (s.closed) p.close();
      canvas.drawPath(p, s.filled ? fill : line);
    }
  }

  @override
  bool shouldRepaint(_NzIconPainter old) => old.color != color || old.strokes != strokes;
}
