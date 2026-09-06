import 'package:flutter/material.dart';

/// حالات التفقّد الأربع — نظير `AttendanceStatus` في `mousqe_core` بلا اعتماد
/// على الحزمة تفادياً لدائرة استيراد بين `mousqe_ui` و`mousqe_core`.
enum BadgeStatus { present, absent, late, excused }

/// شارة تلوّن حسب الحالة بألوان `design/design-tokens.json → color.status`.
class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge({super.key, required this.status});

  final BadgeStatus status;

  static const _colors = {
    BadgeStatus.present: Color(0xFF177F5C),
    BadgeStatus.absent: Color(0xFFB42318),
    BadgeStatus.late: Color(0xFFC9A227),
    BadgeStatus.excused: Color(0xFF2563EB),
  };

  static const _labels = {
    BadgeStatus.present: 'حاضر',
    BadgeStatus.absent: 'غائب',
    BadgeStatus.late: 'متأخر',
    BadgeStatus.excused: 'مأذون',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        _labels[status]!,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
