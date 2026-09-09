import '../models/enums.dart';

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

/// وثلاثةٌ فوقها تقرأ **النصّ المخزَّن** لا التعداد — 🔄 م.6.4.
///
/// صفوفُ drift تحفظ القيمةَ الخادمية نصّاً (`very_good`) لأنها نُسخت كما وصلت في
/// `sync/pull`، فملفُّ الطالب يعرضها من الصفّ لا من تعدادٍ فُكَّ ترميزُه. وكانت
/// الثلاثةُ مكتوبةً **داخل شاشة الأستاذ**، فلمّا احتاجها ملفُّ الطالب على
/// الديسكتوب رُفعت هنا بدل أن تُنسخ — وإلا افترقت التسميتان عند أوّل تصحيح.
String recitationTypeLabelOf(String value) => switch (value) {
  'murajaa' => 'مراجعة',
  'tilawah' => 'تلاوة',
  _ => 'حفظ',
};

String recitationGradeLabelOf(String value) => switch (value) {
  'excellent' => 'ممتاز',
  'very_good' => 'جيد جداً',
  _ => 'جيد',
};

String pointsReasonLabelOf(String value) =>
    pointsReasonLabels[PointsReason.values.firstWhere(
          (reason) => reason.name == value,
          orElse: () => PointsReason.other,
        )] ??
    'أخرى';
