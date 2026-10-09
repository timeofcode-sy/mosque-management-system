import 'package:flutter/material.dart';

import '../theme.dart';
import 'segmented.dart';

/// The teacher's grade for one recitation (tasmee').
enum NzGrade {
  excellent('ممتاز'),
  veryGood('جيد جدًا'),
  good('جيد'),
  repeat('يُعاد');

  const NzGrade(this.label);

  final String label;
}

/// One tap after each recitation. A recitation to be repeated is marked in danger tones.
class NzGradeChips extends StatelessWidget {
  const NzGradeChips({super.key, required this.value, this.onChanged});

  final NzGrade? value;
  final ValueChanged<NzGrade>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    return NzSegmented<NzGrade>(
      label: 'تقدير التسميع',
      selected: value,
      onChanged: onChanged,
      segments: [
        for (final g in NzGrade.values)
          NzSegment(
            value: g,
            label: g.label,
            selectedBackground: g == NzGrade.repeat ? c.dangerSoft : c.primary,
            selectedForeground: g == NzGrade.repeat ? c.danger : c.onPrimary,
          ),
      ],
    );
  }
}
