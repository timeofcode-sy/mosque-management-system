import 'enums.dart';

/// `institute.points` في `/bootstrap` — نظير `App\Support\PointsSettings::toArray()`،
/// ✅ م.6.6.
///
/// **ولماذا تصل في اللقطة أصلاً؟** لأن `institutes.settings` جدولٌ **لا يُزامَن**
/// ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md))، والعميلُ هو من
/// يحسب الإحصاءَ المشتقّ. فتقريرُ النقاط يجمع نقاطَ الحضور بقيمِ المعهد، وهي
/// قيمٌ لا تصل في أيّ تيّار.
///
/// وهذه **ثالثةُ مرّةٍ يتكرّر فيها النمط نفسُه** في هذا المشروع: ما يُحسب محلياً
/// يحتاج ثابتاً خادمياً، فيُحمَل في `/bootstrap` لا في جدولٍ يُزامَن — سبقتها
/// `theme` (م.5.2) و`attendance.late_grace_minutes` (م.5.3)، وهذه الأخيرةُ في
/// **نفس الحقل المجاور** حرفياً.
///
/// و**بلا freezed عمداً:** الحمولةُ خرائطُ متداخلة بمفاتيحَ نصّية (`attendance` و
/// `grade_multiplier`)، ونمذجتُها صفوفاً يعني صفَّين إضافيَّين لا يُقرآن إلا من
/// هنا. والافتراضياتُ هي **نفسُ `PointsSettings::DEFAULTS`**، فخادمٌ أقدم من م.6.6
/// لا يبعث الحقل يبقى عاملاً بها لا بأصفار.
class PointsSettings {
  const PointsSettings({
    this.quranPer15Lines = 10,
    this.hadithPerItem = 5,
    this.mutunPerBayt = 1,
    this.presentPoints = 2,
    this.latePoints = 1,
    this.excusedPoints = 0,
    this.absentPoints = 0,
  });

  final double quranPer15Lines;
  final double hadithPerItem;
  final double mutunPerBayt;

  final double presentPoints;
  final double latePoints;
  final double excusedPoints;
  final double absentPoints;

  /// نقاطُ صفِّ حضورٍ واحد بحالته.
  double attendance(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => presentPoints,
        AttendanceStatus.late => latePoints,
        AttendanceStatus.excused => excusedPoints,
        AttendanceStatus.absent => absentPoints,
      };

  factory PointsSettings.fromJson(Map<String, dynamic> json) {
    final attendance = (json['attendance'] as Map?)?.cast<String, dynamic>();

    const fallback = PointsSettings();

    double read(dynamic value, double orElse) =>
        value is num ? value.toDouble() : orElse;

    return PointsSettings(
      quranPer15Lines:
          read(json['quran_per_15_lines'], fallback.quranPer15Lines),
      hadithPerItem: read(json['hadith_per_item'], fallback.hadithPerItem),
      mutunPerBayt: read(json['mutun_per_bayt'], fallback.mutunPerBayt),
      presentPoints:
          read(attendance?['present'], fallback.presentPoints),
      latePoints: read(attendance?['late'], fallback.latePoints),
      excusedPoints: read(attendance?['excused'], fallback.excusedPoints),
      absentPoints: read(attendance?['absent'], fallback.absentPoints),
    );
  }

  Map<String, dynamic> toJson() => {
        'quran_per_15_lines': quranPer15Lines,
        'hadith_per_item': hadithPerItem,
        'mutun_per_bayt': mutunPerBayt,
        'attendance': {
          'present': presentPoints,
          'late': latePoints,
          'excused': excusedPoints,
          'absent': absentPoints,
        },
      };
}
