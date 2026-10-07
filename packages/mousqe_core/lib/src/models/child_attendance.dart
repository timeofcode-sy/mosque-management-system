import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'child_attendance.freezed.dart';
part 'child_attendance.g.dart';

/// سجلُّ حضورٍ واحد كما تعيده نقاطُ ولي الأمر والطالب — نظيرُ `AttendanceResource`.
///
/// **و[sessionDate] هو يومُ الحضور، [recordedAt] لحظةُ كتابة الأستاذ.** الفرقُ
/// بينهما ليس تفصيلاً: أستاذٌ يصحّح جلسةَ أمس اليومَ يكتب [recordedAt] اليومَ،
/// فمن يرتّب بها يضع سجلَّ أمس في يوم اليوم. **فالعرضُ يقرأ [sessionDate] دائماً**
/// ([CHECKPOINT-PHASE-7.1.MD §3](../../../../../docs/CHECKPOINT-PHASE-7.1.MD)).
///
/// و[sessionDate] `null` حيث لم يحمّل الخادمُ العلاقة (`whenLoaded`) — وهو ما لا
/// يقع في نقاط ولي الأمر، لكنّ النوعَ يقولها بدل أن يفترضها.
@freezed
abstract class ChildAttendanceRow with _$ChildAttendanceRow {
  const factory ChildAttendanceRow({
    required String uuid,
    required AttendanceStatus status,
    String? sessionDate,
    int? lateMinutes,
    String? note,
    String? recordedAt,
  }) = _ChildAttendanceRow;

  factory ChildAttendanceRow.fromJson(Map<String, dynamic> json) =>
      _$ChildAttendanceRowFromJson(json);
}

/// توزيعُ حالات الحضور عبر السجلّ كلِّه — الجزءُ `summary` من الاستجابة.
///
/// [rate] `null` إن لا سجلَّ **قابلاً للقياس**: المأذونُ خارج المقام، فطالبٌ كلُّ
/// سجلّاته أعذارٌ لا نسبةَ له — لا نسبتُه صفر.
@freezed
abstract class ChildAttendanceSummary with _$ChildAttendanceSummary {
  const factory ChildAttendanceSummary({
    @Default(0) int present,
    @Default(0) int absent,
    @Default(0) int late,
    @Default(0) int excused,
    @Default(0) int total,
    double? rate,
  }) = _ChildAttendanceSummary;

  factory ChildAttendanceSummary.fromJson(Map<String, dynamic> json) =>
      _$ChildAttendanceSummaryFromJson(json);
}

/// يومٌ في منحنى الثلاثين — [API.md §3.6](../../../../../docs/API.md).
///
/// 🔑 **[rate] `null` تعني «لم يُقَس» لا «صفر»**: يومٌ بلا جلسة، أو يومٌ كلُّ
/// سجلّاته مأذونة. وهي قاعدةُ م.6.6 نفسُها، وقد صارت في الخادم في م.7.1 — فمن
/// يرسم المنحنى **يتخطّى هذه الأيام ولا يهبط بها إلى القاع**، ومن يكتب رقماً
/// يكتب «لا جلسة».
@freezed
abstract class ChildAttendanceDay with _$ChildAttendanceDay {
  const ChildAttendanceDay._();

  const factory ChildAttendanceDay({
    required String date,
    double? rate,
    @Default(0) int sessions,
  }) = _ChildAttendanceDay;

  factory ChildAttendanceDay.fromJson(Map<String, dynamic> json) =>
      _$ChildAttendanceDayFromJson(json);

  /// هل قِيس هذا اليوم أصلاً؟ — الشرطُ الذي يُرشَّح به المنحنى قبل رسمه.
  bool get isMeasured => rate != null;
}

/// استجابةُ `GET /guardian/children/{uuid}/attendance` كاملةً — وشكلُها شكلُ
/// `/student/me/attendance` نفسُه ([API.md §3.6](../../../../../docs/API.md)).
@freezed
abstract class ChildAttendance with _$ChildAttendance {
  const factory ChildAttendance({
    required ChildAttendanceSummary summary,
    @Default(<ChildAttendanceDay>[]) List<ChildAttendanceDay> trend,
    @Default(<ChildAttendanceRow>[]) List<ChildAttendanceRow> recent,
  }) = _ChildAttendance;

  factory ChildAttendance.fromJson(Map<String, dynamic> json) =>
      _$ChildAttendanceFromJson(json);
}
