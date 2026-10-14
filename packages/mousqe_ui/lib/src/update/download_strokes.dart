import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// تقدّمُ التنزيل بثلاثين خطّاً بزاوية الشعار — شريطُ الأجزاء نفسُه ([NzJuzProgress]): ما وصل
/// أخضرُ عميق، والخطُّ الذي يُملأ الآن نحاسيٌّ أطول ينبض، وما بقي بلون الحدود.
class DownloadStrokes extends StatefulWidget {
  const DownloadStrokes({
    super.key,
    required this.fraction,
    this.active = true,
    this.height = 22,
    this.semanticLabel,
  });

  /// من 0 إلى 1، أو `null` حين لا يُعرف الكلُّ.
  final double? fraction;

  /// ينبض الخطُّ الجاري ما دام التنزيلُ جارياً.
  final bool active;
  final double height;
  final String? semanticLabel;

  static const int strokes = 30;

  @override
  State<DownloadStrokes> createState() => _DownloadStrokesState();
}

class _DownloadStrokesState extends State<DownloadStrokes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(DownloadStrokes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.active && !_reduceMotion;

    if (animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animate && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  bool get _reduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final target = widget.fraction ?? 0;

    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, fraction, _) => AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => SizedBox(
            height: widget.height + widget.height * 0.35,
            width: double.infinity,
            child: CustomPaint(
              painter: _StrokesPainter(
                fraction: widget.fraction == null ? null : fraction,
                rtl: rtl,
                height: widget.height,
                done: c.primary,
                head: c.progressCurrent.withValues(
                  alpha: 0.55 + 0.45 * _pulse.value,
                ),
                rest: c.line,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter({
    required this.fraction,
    required this.rtl,
    required this.height,
    required this.done,
    required this.head,
    required this.rest,
  });

  final double? fraction;
  final bool rtl;
  final double height;
  final Color done;
  final Color head;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    const count = DownloadStrokes.strokes;
    const gap = 3.0;
    final width = (size.width - gap * (count - 1)) / count;
    final rise = width * nzSlope;
    final filled = fraction == null ? 0 : (fraction! * count).floor();
    final complete = fraction != null && fraction! >= 1;

    for (var index = 0; index < count; index++) {
      final isDone = index < filled;
      final isHead = !complete && fraction != null && index == filled;
      final h = isHead ? size.height : height;
      final x = rtl
          ? size.width - (index + 1) * width - index * gap
          : index * (width + gap);
      final top = size.height - h;

      final path = Path()
        ..moveTo(x, top + rise)
        ..lineTo(x + width, top)
        ..lineTo(x + width, size.height)
        ..lineTo(x, size.height)
        ..close();

      canvas.drawPath(
        path,
        Paint()..color = isDone ? done : (isHead ? head : rest),
      );
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      old.fraction != fraction ||
      old.head != head ||
      old.done != done ||
      old.rest != rest ||
      old.rtl != rtl;
}
