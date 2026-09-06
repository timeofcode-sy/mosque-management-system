import 'dart:convert';

import 'package:mousqe_core/mousqe_core.dart';

/// لقطة `GET /bootstrap` ([API.md §3.4](../../../../../docs/API.md)) محفوظةً كما
/// وصلت، فيقلع التطبيق بهويّة معهده وثيمه **قبل** أن تفتح الشبكة.
///
/// تُخزَّن نصّاً خاماً في `app_state`: إعادةُ ترميزها إلى أعمدة تعني هجرةَ مخطّطٍ
/// كلّما أضاف الخادمُ حقلاً، وهو حرّ في ذلك ([API.md §7](../../../../../docs/API.md)).
class BootstrapSnapshot {
  const BootstrapSnapshot({
    required this.userName,
    required this.roles,
    required this.teacherUuid,
    required this.institute,
    required this.courseUuid,
    required this.courseName,
    required this.circles,
  });

  /// مفتاحُه في [AppDatabase.readAppState].
  static const String storageKey = 'bootstrap';

  final String userName;
  final List<String> roles;

  /// معرّف صفّ الأستاذ — به وحده يرشّح العميل «حلقاتي» من مخزنه المحلي، لأن
  /// السحب معهدٌ كامل ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 7).
  final String? teacherUuid;

  final Institute institute;
  final String? courseUuid;
  final String? courseName;

  /// حلقات الأستاذ كما رآها الخادم لحظةَ اللقطة — تُعرَض حتى قبل أن يصل
  /// `course_circle_teachers` في أول سحب.
  final List<CourseCircle> circles;

  bool get isTeacher => roles.contains('teacher');

  bool get hasCurrentCourse => courseUuid != null;

  factory BootstrapSnapshot.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final course = (json['course'] as Map?)?.cast<String, dynamic>();

    return BootstrapSnapshot(
      userName: user['name'] as String? ?? '',
      roles: (user['roles'] as List<dynamic>? ?? const []).cast<String>(),
      teacherUuid: user['teacher_uuid'] as String?,
      institute: Institute.fromJson(
        (json['institute'] as Map).cast<String, dynamic>(),
      ),
      courseUuid: course?['uuid'] as String?,
      courseName: course?['name'] as String?,
      circles: [
        for (final circle in json['circles'] as List<dynamic>? ?? const [])
          CourseCircle.fromJson((circle as Map).cast<String, dynamic>()),
      ],
    );
  }

  static BootstrapSnapshot? decode(String? raw) {
    if (raw == null) {
      return null;
    }

    try {
      return BootstrapSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      // لقطةٌ من إصدارٍ أقدم لم يعد شكلُها مقروءاً — تُهمَل ويُعاد جلبُها.
      return null;
    }
  }
}
