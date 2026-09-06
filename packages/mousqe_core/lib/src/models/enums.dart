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
  excused,
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
