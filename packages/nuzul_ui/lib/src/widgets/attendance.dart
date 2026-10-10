import 'package:flutter/material.dart';

import '../generated/tokens.dart';
import '../icons.dart';
import '../theme.dart';
import 'segmented.dart';

/// Attendance of a student in one session. The order is the order of the choices.
enum NzAttendance {
  present('حاضر', NzIcons.check),
  late('متأخر', NzIcons.clock),
  excused('غائب بعذر', NzIcons.note),
  absent('غائب', NzIcons.close);

  const NzAttendance(this.label, this.icon);

  /// The fixed Arabic word for the status.
  final String label;
  final String icon;

  /// (foreground, background) of the status in the current theme.
  (Color, Color) colors(NzColorTokens c) => switch (this) {
        NzAttendance.present => (c.success, c.successSoft),
        NzAttendance.late => (c.warning, c.warningSoft),
        NzAttendance.excused => (c.info, c.infoSoft),
        NzAttendance.absent => (c.danger, c.dangerSoft),
      };
}

/// Shows a status as a word and an icon; colour never carries the meaning alone.
class NzAttendanceBadge extends StatelessWidget {
  const NzAttendanceBadge(this.status, {super.key, this.text});

  final NzAttendance status;

  /// Replaces the default word, e.g. «متأخر ١٠ د».
  final String? text;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = status.colors(context.nz);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(NzSpace.s2, 2, NzSpace.s3, 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NzRadius.sm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        NzIcon(status.icon, size: 16, color: fg),
        const SizedBox(width: NzSpace.s1),
        Text(text ?? status.label, style: NzType.label.copyWith(color: fg)),
      ]),
    );
  }
}

/// One student in the session's attendance sheet with the four-way choice.
/// Stacks the choices under the name when the row is narrower than 420px.
class NzAttendanceRow extends StatelessWidget {
  const NzAttendanceRow({super.key, required this.name, this.detail, this.status, this.onChanged});

  final String name;
  final String? detail;
  final NzAttendance? status;
  final ValueChanged<NzAttendance>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final who = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(name, style: NzType.body.copyWith(fontWeight: FontWeight.w600, color: c.ink)),
      if (detail != null) Text(detail!, style: NzType.caption.copyWith(color: c.inkMuted)),
    ]);
    final choices = NzSegmented<NzAttendance>(
      label: 'حضور $name',
      selected: status,
      onChanged: onChanged,
      segments: [
        for (final s in NzAttendance.values)
          NzSegment(
            value: s,
            label: s.label,
            icon: s.icon,
            selectedBackground: s.colors(c).$2,
            selectedForeground: s.colors(c).$1,
          ),
      ],
    );
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s4, vertical: NzSpace.s3),
      decoration: BoxDecoration(color: c.surfaceRaised, border: Border(bottom: BorderSide(color: c.line))),
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 420) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            who,
            const SizedBox(height: NzSpace.s2),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: choices),
          ]);
        }
        return Row(children: [Expanded(child: who), const SizedBox(width: NzSpace.s4), choices]);
      }),
    );
  }
}
