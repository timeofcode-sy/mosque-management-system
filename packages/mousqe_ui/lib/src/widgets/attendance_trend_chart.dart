import 'package:flutter/material.dart';

/// يومٌ في منحنى الحضور — **سجلٌّ لا نموذجٌ مستورَد** (انظر [Loaded] في
/// `snapshot_view.dart`): `rate` بـ`null` تعني «لم يُقَس».
typedef TrendDay = ({String date, double? rate, int sessions});

/// منحنى آخرِ ثلاثين يوماً — **يصل أيامَ التفقّد بعضَها ببعض ويتخطّى ما بينها**.
///
/// 🔑 `rate` بـ`null` تعني «لم يُقَس» لا «صفر»، فلا نقطةَ لليوم ولا يمرّ به الخطّ.
/// ولو رُسم صفراً لَهبط المنحنى إلى القاع في كل جمعةٍ وعطلة، **فيبدو منحنى طالبٍ
/// مواظبٍ مسنَّناً بين المئة والصفر** — وهو نفسُ العطب الذي أُصلح في مكوّن اللوحة
/// في م.7.1.
///
/// وبلا مكتبة مخطّطات: `CustomPainter` خالص.
///
/// 🔁 **رُفع من `apps/guardian/` في م.8.2** حين احتاجه تطبيقُ الطالب.
class AttendanceTrendChart extends StatelessWidget {
  const AttendanceTrendChart({
    super.key,
    required this.days,
    this.heading = 'منحنى الحضور — آخر ٣٠ يوماً',
  });

  final List<TrendDay> days;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final measured = days.where((day) => day.rate != null).toList(growable: false);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(heading, style: theme.textTheme.titleSmall),
                if (measured.isNotEmpty)
                  Text('${measured.length} يوم تفقّد', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            if (measured.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'لا جلساتٍ مغلقة بعد — يظهر المنحنى بعد أوّل تفقّد مكتمل.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 140,
                child: CustomPaint(
                  painter: _TrendPainter(
                    days: days,
                    line: theme.colorScheme.primary,
                    grid: theme.colorScheme.outlineVariant,
                    fill: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.days,
    required this.line,
    required this.grid,
    required this.fill,
  });

  final List<TrendDay> days;
  final Color line;
  final Color grid;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) {
      return;
    }

    const padY = 10.0;
    final usable = size.height - 2 * padY;
    final step = days.length > 1 ? size.width / (days.length - 1) : 0.0;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (final gridline in [25.0, 50.0, 75.0]) {
      final y = padY + usable * (100 - gridline) / 100;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // المقياسُ يبقى على المحور الأصلي، والنقاطُ **المقيسةُ وحدها** تدخل المسار —
    // فالفجوةُ فجوةٌ لا هبوط.
    final points = <Offset>[];

    for (var i = 0; i < days.length; i++) {
      final rate = days[i].rate;

      if (rate == null) {
        continue;
      }

      final clamped = rate.clamp(0, 100).toDouble();
      points.add(Offset(i * step, padY + usable * (100 - clamped) / 100));
    }

    if (points.isEmpty) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    // المساحةُ تُغلَق تحت أوّلِ نقطةٍ مقيسة وآخرِها لا تحت حافّتَي الصندوق، وإلا
    // امتدّ ظلُّها فوق مدىً لا قياسَ فيه.
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = line;

    for (final point in points) {
      canvas.drawCircle(point, 3, dot);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.days != days || old.line != line || old.grid != grid || old.fill != fill;
}
