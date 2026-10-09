import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// حالات التفقّد الأربع — نظير `AttendanceStatus` في `mousqe_core` بلا اعتماد
/// على الحزمة تفادياً لدائرة استيراد بين `mousqe_ui` و`mousqe_core`.
enum BadgeStatus {
  present,
  absent,
  late,
  excused;

  /// 🔁 **م.8.2: يقرأ قيمةَ العقد النصّية — فتزول ترجمةٌ كانت تتكرّر في كل تطبيق.**
  ///
  /// كانت كلُّ واجهةٍ تكتب `badgeOf(AttendanceStatus)` بأربعة أسطر، وبلغت ثلاثةَ
  /// أسطح في م.7.3 حيث سُجّل أنها **لا تُرفَع**: `mousqe_ui` لا تعتمد
  /// `mousqe_core`، ورفعُها إلى الأخيرة يقلب الاتجاه إلى ما هو أسوأ — طبقةُ
  /// بياناتٍ تعرف ودجت.
  ///
  /// والمخرجُ أن **القيمةَ النصّية عقدٌ قائمٌ أصلاً**: `AttendanceStatus.present`
  /// قيمتُها `'present'` في JSON وفي قاعدة الخادم منذ م.1. فتقرؤها الحزمةُ
  /// مباشرةً ولا تحتاج أن تعرف الـenum — فينحلّ ما بدا تعارضاً بين قاعدتين.
  ///
  /// وقيمةٌ لا يعرفها العقد ⇒ [absent]: خادمٌ أحدثُ يضيف حالةً خامسة لا يُسقط
  /// شاشةً، والغيابُ أسلمُ افتراضٍ من الحضور — **لا يُطمئن على ما لم يُقَس**.
  static BadgeStatus fromValue(String value) => switch (value) {
        'present' => BadgeStatus.present,
        'late' => BadgeStatus.late,
        'excused' => BadgeStatus.excused,
        _ => BadgeStatus.absent,
      };
}

/// شارة الحالة بأزواج الهوية الثابتة (حاضر: success · متأخر: warning · مستأذن: info · غائب: danger).
/// تُكتب الحالةُ بكلمتها وأيقونتها دائماً — اللونُ وحده لا يكفي (قاعدة الهوية).
class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge({super.key, required this.status, this.text});

  final BadgeStatus status;

  /// يستبدل الكلمة الافتراضية، مثل «متأخر 10 د».
  final String? text;

  static const _labels = {
    BadgeStatus.present: 'حاضر',
    BadgeStatus.absent: 'غائب',
    BadgeStatus.late: 'متأخر',
    BadgeStatus.excused: 'مأذون',
  };

  static const _nz = {
    BadgeStatus.present: NzAttendance.present,
    BadgeStatus.absent: NzAttendance.absent,
    BadgeStatus.late: NzAttendance.late,
    BadgeStatus.excused: NzAttendance.excused,
  };

  @override
  Widget build(BuildContext context) =>
      NzAttendanceBadge(_nz[status]!, text: text ?? _labels[status]);
}
