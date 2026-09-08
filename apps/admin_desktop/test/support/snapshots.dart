import 'dart:convert';

import 'package:mousqe_core/mousqe_core.dart';

/// صلاحياتُ الأدوار كما تبذرها `RolesAndPermissionsSeeder` على الخادم.
///
/// نسخةُ اختبارٍ لا نسخةُ إنتاج: التطبيق يقرأ الصلاحيات من `/bootstrap` ولا
/// يعرف كتالوجاً — وهو القرار 3 في [PHASE-6-STAGES.MD §0]. وما هنا **حمولةُ
/// خادمٍ مصطنعة** ليُختبَر بها الترشيح، فلو افترقت عن البذرة لسقط الاختبار الذي
/// يقارن أبوابَ المشرف بأبواب مدير المعهد لا الواقعُ.
class SeededRoles {
  const SeededRoles._();

  static const List<String> all = [
    'institutes.view', 'institutes.manage',
    'courses.view', 'courses.manage',
    'shifts.manage',
    'circles.view', 'circles.manage',
    'students.view', 'students.manage',
    'teachers.view', 'teachers.manage',
    'guardians.view', 'guardians.manage',
    'enrollments.manage', 'transfers.manage',
    'attendance.view', 'attendance.take', 'attendance.amend', 'attendance.lock',
    'excuses.submit', 'excuses.review',
    'curricula.manage', 'progress.view', 'progress.manage',
    'evaluations.view', 'evaluations.manage',
    'reports.view', 'reports.export',
    'customfields.manage', 'tags.manage',
    'announcements.view', 'announcements.manage',
    'settings.manage', 'users.manage', 'users.invite',
    'credentials.export', 'credentials.manage',
    'sync.pull', 'sync.push', 'conflicts.review',
    'system.debug',
  ];

  /// المبرمج يملك كل شيء.
  static const List<String> developer = all;

  /// مديرُ المعهد مثلَه داخل معهده وحده: لا ينشئ معهداً ولا يبدّل بين المعاهد.
  static final List<String> admin = [
    for (final permission in all)
      if (permission != 'system.debug' && permission != 'institutes.manage')
        permission,
  ];

  static const List<String> supervisor = [
    'institutes.view', 'courses.view', 'circles.view', 'students.view',
    'students.manage', 'teachers.view', 'guardians.view', 'enrollments.manage',
    'transfers.manage', 'attendance.view', 'attendance.take',
    'attendance.amend', 'attendance.lock', 'excuses.review', 'progress.view',
    'progress.manage', 'evaluations.view', 'evaluations.manage', 'reports.view',
    'reports.export', 'announcements.view', 'announcements.manage',
    'credentials.export', 'credentials.manage',
    'sync.pull', 'sync.push', 'conflicts.review',
  ];

  static const List<String> teacher = [
    'circles.view', 'students.view', 'attendance.view', 'attendance.take',
    'progress.view', 'progress.manage', 'evaluations.view',
    'evaluations.manage', 'excuses.review', 'reports.view',
    'announcements.view', 'sync.pull', 'sync.push',
  ];
}

Map<String, dynamic> bootstrapBody({
  required List<String> permissions,
  String role = 'supervisor',
  String instituteUuid = 'ins-1',
  String instituteName = 'معهد النور',
}) => {
      'user': {
        'name': 'سعيد بن أحمد',
        'roles': [role],
        'permissions': permissions,
        'teacher_uuid': null,
      },
      'institute': {
        'uuid': instituteUuid,
        'name': instituteName,
        'logo_path': null,
        'theme': {
          'primary': '#0F5132',
          'secondary': '#C9A227',
          'surface': '#F7F3EA',
        },
        'attendance': {'late_grace_minutes': 5},
      },
      'course': {'uuid': 'crs-1', 'name': 'دورة 1447'},
      'circles': <Map<String, dynamic>>[],
    };

BootstrapSnapshot snapshotOf(List<String> permissions) =>
    BootstrapSnapshot.fromJson(bootstrapBody(permissions: permissions));

String encodedSnapshot(List<String> permissions) =>
    jsonEncode(bootstrapBody(permissions: permissions));
