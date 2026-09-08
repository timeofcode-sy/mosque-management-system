import 'dart:convert';

import 'institute.dart';
import 'course_circle.dart';

/// لقطة `GET /bootstrap` ([API.md §3.4](../../../../../docs/API.md)) محفوظةً كما
/// وصلت، فيقلع التطبيق بهويّة معهده وثيمه **قبل** أن تفتح الشبكة.
///
/// تُخزَّن نصّاً خاماً في `app_state`: إعادةُ ترميزها إلى أعمدة تعني هجرةَ مخطّطٍ
/// كلّما أضاف الخادمُ حقلاً، وهو حرّ في ذلك ([API.md §7](../../../../../docs/API.md)).
///
/// 🔄 م.6.3 — رُفعت من `apps/teacher/` إلى الحزمة حين احتاجها الديسكتوب، ومعها
/// [permissions]: عليها يبني الديسكتوبُ أبوابَه، لأن الفرق بين المشرف ومديرِ
/// المعهد **صلاحياتٌ لا نسخةُ برنامج** ([APPS-FEATURES.md §4.1]).
class BootstrapSnapshot {
  const BootstrapSnapshot({
    required this.userName,
    required this.roles,
    required this.permissions,
    required this.teacherUuid,
    required this.institute,
    required this.courseUuid,
    required this.courseName,
    required this.circles,
  });

  /// مفتاحُه في `AppDatabase.readAppState`.
  static const String storageKey = 'bootstrap';

  final String userName;
  final List<String> roles;

  /// صلاحياتُ المستخدم **داخل المعهد العامل** — لا أسماءُ أدواره.
  ///
  /// يحسبها `ApiScope::permissions()` بـ`can()` لكل صلاحية، فتشمل ما تمنحه
  /// الأدوارُ العابرة عبر `Gate::before` ولا يظهر في إسنادات المعهد.
  final List<String> permissions;

  /// معرّف صفّ الأستاذ — به وحده يرشّح العميل «حلقاتي» من مخزنه المحلي، لأن
  /// السحب معهدٌ كامل ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 7).
  final String? teacherUuid;

  final Institute institute;
  final String? courseUuid;
  final String? courseName;

  /// حلقاتُ صاحب الحساب كما رآها الخادم لحظةَ اللقطة — حلقاتُ الأستاذ، أو حلقاتُ
  /// الدورة كلُّها لمن يملك `circles.view`. تُعرَض حتى قبل أن يكتمل أوّلُ سحب.
  final List<CourseCircle> circles;

  bool get isTeacher => roles.contains('teacher');

  bool get hasCurrentCourse => courseUuid != null;

  int get lateGraceMinutes => institute.attendance.lateGraceMinutes;

  /// هل يملك المستخدم هذه الصلاحية في معهده العامل؟
  bool can(String permission) => permissions.contains(permission);

  /// هل يملك **واحدةً** من هذه الصلاحيات؟ — بابٌ يُفتح بأيٍّ منها.
  bool canAny(Iterable<String> candidates) => candidates.any(can);

  factory BootstrapSnapshot.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final course = (json['course'] as Map?)?.cast<String, dynamic>();

    return BootstrapSnapshot(
      userName: user['name'] as String? ?? '',
      roles: (user['roles'] as List<dynamic>? ?? const []).cast<String>(),
      // خادمٌ أقدم من م.6.1 لا يبعث الحقل — قائمةٌ فارغة تعني «بلا بابٍ» لا
      // «بكل الأبواب»: الواجهةُ تُخفي ما لا تتيقّن منه.
      permissions:
          (user['permissions'] as List<dynamic>? ?? const []).cast<String>(),
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
    } on Object {
      // لقطةٌ من إصدارٍ أقدم لم يعد شكلُها مقروءاً — تُهمَل ويُعاد جلبُها.
      //
      // وكلُّ خطأ لا `FormatException` وحدها: نصٌّ مشوّه يرميها، لكن لقطةً كاملةَ
      // التركيب ينقصها `institute` ترمي `TypeError` — وهي الحالةُ الأرجح، لأن
      // الخادم حرٌّ في تغيير شكل حقوله ([API.md §7]). ولقطةٌ لا تُقرأ ليست عطباً
      // يُوقف الإقلاع: الجهاز يعمل بلا لقطة حتى يعود أوّلُ `/bootstrap` ناجحاً.
      return null;
    }
  }
}
