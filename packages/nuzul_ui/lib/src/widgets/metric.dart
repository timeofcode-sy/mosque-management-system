import 'package:flutter/material.dart';

import '../generated/tokens.dart';
import '../theme.dart';

/// Tone of a metric's comparison line.
enum NzTone { neutral, success, danger }

/// One figure that is the point of a dashboard panel (supervisor and administration only).
class NzMetric extends StatelessWidget {
  const NzMetric({super.key, required this.label, required this.value, this.hint, this.tone = NzTone.neutral});

  final String label;

  /// Already in Arabic-Indic digits (see `nzDigits`).
  final String value;
  final String? hint;
  final NzTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final hintColor = switch (tone) {
      NzTone.success => c.success,
      NzTone.danger => c.danger,
      NzTone.neutral => c.inkMuted,
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s5, vertical: NzSpace.s4),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(NzRadius.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: NzType.label.copyWith(color: c.inkMuted)),
        Text(value, style: NzType.display2.copyWith(color: c.ink, height: 44 / 34)),
        if (hint != null) Text(hint!, style: NzType.caption.copyWith(color: hintColor)),
      ]),
    );
  }
}
