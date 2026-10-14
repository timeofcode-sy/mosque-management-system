import 'package:flutter/material.dart';

import '../digits.dart';
import '../generated/tokens.dart';
import '../theme.dart';

/// The thirty ajza as thirty strokes cut at the roof angle: memorised, being memorised, remaining.
///
/// Juz 1 sits at the start (the right in Arabic). The juz being memorised stands taller, a cue that is
/// not colour alone.
class NzJuzProgress extends StatelessWidget {
  const NzJuzProgress({super.key, required this.memorized, this.current, this.compact = false, this.showLabel = true});

  /// Counts back from juz 30 (عمّ), the usual order in halaqat.
  NzJuzProgress.count(int count, {Key? key, int? current, bool compact = false, bool showLabel = true})
      : this(
          key: key,
          memorized: {for (var j = 30; j > 30 - count; j--) j},
          current: current,
          compact: compact,
          showLabel: showLabel,
        );

  final Set<int> memorized;
  final int? current;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final summary = 'محفوظ ${nzDigits(memorized.length)} من 30 جزءًا';
    final h = compact ? 16.0 : 26.0;
    return Semantics(
      label: current == null ? summary : '$summary، يحفظ الآن الجزء ${nzDigits(current!)}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: NzSpace.s2),
            child: Row(children: [
              Expanded(child: Text(summary, style: NzType.label.copyWith(fontWeight: FontWeight.w600, color: c.ink))),
              if (current != null)
                Text('يحفظ الآن: الجزء ${nzDigits(current!)}', style: NzType.label.copyWith(color: c.inkMuted)),
            ]),
          ),
        SizedBox(
          height: h + (compact ? 6 : 8),
          child: CustomPaint(
            painter: _JuzPainter(
              memorized: memorized,
              current: current,
              height: h,
              rtl: Directionality.of(context) == TextDirection.rtl,
              done: c.primary,
              now: c.progressCurrent,
              rest: c.line,
            ),
          ),
        ),
      ]),
    );
  }
}

class _JuzPainter extends CustomPainter {
  _JuzPainter({
    required this.memorized,
    required this.current,
    required this.height,
    required this.rtl,
    required this.done,
    required this.now,
    required this.rest,
  });

  final Set<int> memorized;
  final int? current;
  final double height;
  final bool rtl;
  final Color done;
  final Color now;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final w = (size.width - gap * 29) / 30;
    final rise = w * nzSlope;
    for (var j = 1; j <= 30; j++) {
      final isNow = j == current && !memorized.contains(j);
      final h = isNow ? size.height : height;
      final x0 = rtl ? size.width - j * (w + gap) + gap : (j - 1) * (w + gap);
      final top = size.height - h;
      final p = Path()
        ..moveTo(x0, top + rise)
        ..lineTo(x0 + w, top)
        ..lineTo(x0 + w, size.height)
        ..lineTo(x0, size.height)
        ..close();
      canvas.drawPath(p, Paint()..color = memorized.contains(j) ? done : (isNow ? now : rest));
    }
  }

  @override
  bool shouldRepaint(_JuzPainter old) =>
      old.memorized != memorized || old.current != current || old.done != done || old.rtl != rtl;
}
