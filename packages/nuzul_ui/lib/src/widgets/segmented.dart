import 'package:flutter/material.dart';

import '../generated/tokens.dart';
import '../icons.dart';
import '../theme.dart';

/// One choice of an [NzSegmented] control.
class NzSegment<T> {
  const NzSegment({
    required this.value,
    required this.label,
    this.icon,
    required this.selectedBackground,
    required this.selectedForeground,
  });

  final T value;
  final String label;
  final String? icon;
  final Color selectedBackground;
  final Color selectedForeground;
}

/// A one-tap choice between a few options (attendance status, recitation grade).
/// Accessible as a group of mutually exclusive buttons.
class NzSegmented<T> extends StatelessWidget {
  const NzSegmented({super.key, required this.segments, required this.selected, this.onChanged, this.label});

  final List<NzSegment<T>> segments;
  final T? selected;
  final ValueChanged<T>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final dense = Theme.of(context).visualDensity == VisualDensity.compact;
    final h = dense ? NzSize.controlHeightDense : NzSize.controlHeight;
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final on = s.value == selected;
      final fg = on ? s.selectedForeground : c.inkMuted;
      if (i > 0) children.add(Container(width: 1, height: h, color: c.line));
      children.add(Semantics(
        button: true,
        selected: on,
        inMutuallyExclusiveGroup: true,
        label: s.label,
        excludeSemantics: true,
        child: Material(
          color: on ? s.selectedBackground : c.surfaceRaised,
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged!(s.value),
            focusColor: c.focus.withValues(alpha: 0.2),
            child: Container(
              height: h,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s3),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (s.icon != null) ...[NzIcon(s.icon!, size: 16, color: fg), const SizedBox(width: NzSpace.s1)],
                Text(s.label,
                    style: NzType.label.copyWith(color: fg, fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ));
    }
    return Semantics(
      label: label,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(NzRadius.sm),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NzRadius.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
