import 'package:json_annotation/json_annotation.dart';

/// حالة الطالب أو الحلقة أو الدورة العامة — نص حرفي كما يعود من الخادم.
enum EntityStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
  @JsonValue('draft')
  draft,
  @JsonValue('completed')
  completed,
  @JsonValue('locked')
  locked,
}

/// حالة تفقّد الطالب أو الأستاذ.
enum AttendanceStatus {
  @JsonValue('present')
  present,
  @JsonValue('absent')
  absent,
  @JsonValue('late')
  late,
  @JsonValue('excused')
  excused;

  /// قيمةُ العقد النصّية — نظيرُ `->value` في enum الخادم ✅ م.8.2.
  ///
  /// `@JsonValue` يوجّه المولِّدَ ولا يترك في زمن التشغيل ما يُقرأ، فكان كلُّ
  /// سطحٍ يحتاج النصَّ يكتب `switch` من أربعة أسطر — وبلغت ثلاثةَ أسطح.
  /// وباستخراجها هنا تقرأ `mousqe_ui` الحالةَ **بقيمتها لا بنوعها**
  /// (`BadgeStatus.fromValue`)، فتزول الترجمةُ المكرَّرة **بلا أن تعتمد حزمةُ
  /// العرض على حزمة البيانات**.
  String get value => switch (this) {
        AttendanceStatus.present => 'present',
        AttendanceStatus.absent => 'absent',
        AttendanceStatus.late => 'late',
        AttendanceStatus.excused => 'excused',
      };
}

/// حالة إذن الغياب.
enum ExcuseStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

/// حالةُ بندٍ في محفوظات الطالب — نظيرُ `App\Enums\ProgressStatus`.
///
/// ✅ م.7.2. و`notStarted` **لا تصل في نقاط التقدُّم**: الخادمُ يرشّحها
/// (`in_progress` و`memorized` و`mastered` وحدها)، لكنها في الكتالوج لأن الصفَّ
/// نفسَه يصل في `sync/pull` إلى أجهزة الطاقم بها.
enum ProgressStatus {
  @JsonValue('not_started')
  notStarted,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('memorized')
  memorized,
  @JsonValue('mastered')
  mastered,
}

/// نوع التسميع.
enum RecitationType {
  @JsonValue('hifz')
  hifz,
  @JsonValue('murajaa')
  murajaa,
  @JsonValue('tilawah')
  tilawah,
}

/// تقدير التسميع.
enum RecitationGrade {
  @JsonValue('excellent')
  excellent,
  @JsonValue('very_good')
  veryGood,
  @JsonValue('good')
  good,
}

/// سبب منح النقاط اليدوية.
enum PointsReason {
  @JsonValue('behavior')
  behavior,
  @JsonValue('participation')
  participation,
  @JsonValue('competition')
  competition,
  @JsonValue('reward')
  reward,
  @JsonValue('excellence')
  excellence,
  @JsonValue('volunteering')
  volunteering,
  @JsonValue('other')
  other,
}
