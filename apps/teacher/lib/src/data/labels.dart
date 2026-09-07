import 'package:mousqe_core/mousqe_core.dart';

/// تسميات التعدادات بالعربية — نظير `PointReason::label()` و`RecitationGrade::label()`
/// على الخادم.
///
/// مجموعةٌ في ملفٍّ واحد لأن الشاشتين تعرضانها: نموذجُ الإدخال وقائمةُ ما سُجّل
/// في شاشة التفقّد. ونسختان منها تفترقان عند أول تسمية تُصحَّح في إحداهما.
const Map<PointsReason, String> pointsReasonLabels = {
  PointsReason.behavior: 'سلوك',
  PointsReason.participation: 'مشاركة',
  PointsReason.competition: 'مسابقة',
  PointsReason.reward: 'مكافأة',
  PointsReason.excellence: 'تميّز',
  PointsReason.volunteering: 'تطوّع',
  PointsReason.other: 'أخرى',
};

const Map<RecitationGrade, String> recitationGradeLabels = {
  RecitationGrade.excellent: 'ممتاز',
  RecitationGrade.veryGood: 'جيد جداً',
  RecitationGrade.good: 'جيد',
};

const Map<RecitationType, String> recitationTypeLabels = {
  RecitationType.hifz: 'حفظ',
  RecitationType.murajaa: 'مراجعة',
  RecitationType.tilawah: 'تلاوة',
};
