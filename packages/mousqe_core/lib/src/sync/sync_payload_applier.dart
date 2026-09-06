import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';

/// يطبّق صفّاً واحداً من `change_log` على drift — [SYNC-PROTOCOL.md §8](../../../../docs/SYNC-PROTOCOL.md)
/// البند 6: `create`/`update` ⇒ `insertOnConflictUpdate` بمطابقة `uuid`، و`delete`
/// ⇒ حذف الصفّ بمطابقة `uuid` (الحمولة `null` في الحذف).
///
/// الحمولة خامة (`$model->toArray()`) لا شكل الـ API Resource — التحويل الوحيد
/// المطلوب هو JSON→drift row، لا إعادة تسمية حقول — بما فيها `id` نفسه: الحمولة
/// تحمل مفاتيحَ أجنبية بمعرّفاتٍ **رقمية خادمية** (`attendance_session_id`،
/// `student_id`…)، فلو تُرك المفتاح الأساسي المحلي لعدّاد drift لَما طابق أيُّ
/// مفتاحٍ أجنبيٍّ صفَّه، ولَبقيت صفوفُ الحضور معلَّقةً بلا جلسة.
///
/// وهي **مرّت بأنواع Eloquent**:
/// عمودٌ عليه `'boolean'` يصل `true` لا `1`، وعمودٌ عليه `'array'` يصل كائناً لا
/// نصّاً، وعمودٌ `decimal` قد يصل نصّاً. لذلك كل قراءة هنا تمرّ بمحوّلٍ متسامح
/// (`_bool` · `_int` · `_double` · `_date` · `_json`) لا بـ`as` مباشرة.
class SyncPayloadApplier {
  SyncPayloadApplier(this._db);

  final AppDatabase _db;

  /// [tableName] كما يصل في `change_log.table_name`، و[operation] هو
  /// `create`/`update`/`delete`، و[rowUuid] هو `change_log.row_uuid`.
  Future<void> apply({
    required String tableName,
    required String operation,
    required String rowUuid,
    Map<String, dynamic>? payload,
  }) async {
    if (operation == 'delete') {
      await _deleteByUuid(tableName, rowUuid);
      return;
    }

    if (payload == null) {
      return;
    }

    await _upsert(tableName, payload);
  }

  Future<void> _upsert(String tableName, Map<String, dynamic> payload) async {
    switch (tableName) {
      case 'institutes':
        await _put(_db.institutes, InstitutesCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          name: payload['name'] as String,
          shortName: Value(payload['short_name'] as String?),
          logoPath: Value(payload['logo_path'] as String?),
          settings: Value(_json(payload['settings'])),
          isActive: Value(_bool(payload['is_active'], orElse: true)),
        ));
      case 'courses':
        await _put(_db.courses, CoursesCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          instituteId: _int(payload['institute_id'])!,
          name: payload['name'] as String,
          startsOn: _date(payload['starts_on'])!,
          endsOn: Value(_date(payload['ends_on'])),
          status: Value(payload['status'] as String? ?? 'draft'),
          isCurrent: Value(_bool(payload['is_current'], orElse: false)),
        ));
      case 'circles':
        await _put(_db.circles, CirclesCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          instituteId: _int(payload['institute_id'])!,
          name: payload['name'] as String,
          level: Value(payload['level'] as String?),
          color: Value(payload['color'] as String?),
          sortOrder: Value(_int(payload['sort_order']) ?? 0),
          isActive: Value(_bool(payload['is_active'], orElse: true)),
        ));
      case 'shifts':
        await _put(_db.shifts, ShiftsCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          courseId: _int(payload['course_id'])!,
          name: payload['name'] as String,
          startsAt: payload['starts_at'] as String,
          endsAt: payload['ends_at'] as String,
          sortOrder: Value(_int(payload['sort_order']) ?? 0),
          isActive: Value(_bool(payload['is_active'], orElse: true)),
        ));
      case 'course_circles':
        await _put(_db.courseCircles, CourseCirclesCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          courseId: _int(payload['course_id'])!,
          circleId: _int(payload['circle_id'])!,
          shiftId: _int(payload['shift_id'])!,
          room: Value(payload['room'] as String?),
          capacity: Value(_int(payload['capacity'])),
          status: Value(payload['status'] as String? ?? 'active'),
        ));
      case 'teachers':
        await _put(_db.teachers, TeachersCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          instituteId: _int(payload['institute_id'])!,
          displayName: payload['display_name'] as String,
          phone: Value(payload['phone'] as String?),
          photoPath: Value(payload['photo_path'] as String?),
          status: Value(payload['status'] as String? ?? 'active'),
        ));
      case 'course_circle_teachers':
        await _put(_db.courseCircleTeachers, CourseCircleTeachersCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          courseCircleId: _int(payload['course_circle_id'])!,
          teacherId: _int(payload['teacher_id'])!,
          role: Value(payload['role'] as String? ?? 'main'),
          joinedOn: Value(_date(payload['joined_on'])),
          leftOn: Value(_date(payload['left_on'])),
        ));
      case 'students':
        await _put(_db.students, StudentsCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          instituteId: _int(payload['institute_id'])!,
          registrationNo: Value(payload['registration_no'] as String?),
          photoPath: Value(payload['photo_path'] as String?),
          firstName: payload['first_name'] as String,
          fatherName: payload['father_name'] as String,
          familyName: payload['family_name'] as String,
          status: Value(payload['status'] as String? ?? 'active'),
        ));
      case 'enrollments':
        await _put(_db.enrollments, EnrollmentsCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          courseCircleId: _int(payload['course_circle_id'])!,
          studentId: _int(payload['student_id'])!,
          status: Value(payload['status'] as String? ?? 'active'),
          enrolledOn: Value(_date(payload['enrolled_on'])),
          leftOn: Value(_date(payload['left_on'])),
        ));
      case 'attendance_sessions':
        await _put(_db.attendanceSessions, AttendanceSessionsCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          courseCircleId: _int(payload['course_circle_id'])!,
          sessionDate: _date(payload['session_date'])!,
          status: Value(payload['status'] as String? ?? 'draft'),
          completedAt: Value(_date(payload['completed_at'])),
        ));
      case 'attendances':
        await _put(_db.attendances, AttendancesCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          attendanceSessionId: _int(payload['attendance_session_id'])!,
          studentId: _int(payload['student_id'])!,
          status: Value(payload['status'] as String? ?? 'present'),
          lateMinutes: Value(_int(payload['late_minutes'])),
          note: Value(payload['note'] as String?),
          notePolarity: Value(payload['note_polarity'] as String?),
          recordedAt: _date(payload['recorded_at'])!,
        ));
      case 'memorization_logs':
        await _put(_db.recitations, RecitationsCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          studentId: _int(payload['student_id'])!,
          courseCircleId: Value(_int(payload['course_circle_id'])),
          attendanceSessionId: Value(_int(payload['attendance_session_id'])),
          curriculumItemId: Value(_int(payload['curriculum_item_id'])),
          date: _date(payload['date'])!,
          type: Value(payload['type'] as String? ?? 'hifz'),
          grade: Value(payload['grade'] as String?),
          fromSurah: Value(_int(payload['from_surah'])),
          fromAyah: Value(_int(payload['from_ayah'])),
          toSurah: Value(_int(payload['to_surah'])),
          toAyah: Value(_int(payload['to_ayah'])),
          lines: Value(_double(payload['lines'])),
          newLines: Value(_double(payload['new_lines'])),
          points: Value(_double(payload['points']) ?? 0),
          juz: Value(_int(payload['juz'])),
          notes: Value(payload['notes'] as String?),
        ));
      case 'absence_excuses':
        await _put(_db.absenceExcusesTable, AbsenceExcusesTableCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          studentId: _int(payload['student_id'])!,
          fromDate: _date(payload['from_date'])!,
          toDate: _date(payload['to_date'])!,
          reason: payload['reason'] as String,
          attachmentPath: Value(payload['attachment_path'] as String?),
          status: Value(payload['status'] as String? ?? 'pending'),
          reviewNote: Value(payload['review_note'] as String?),
        ));
      case 'student_points':
        await _put(_db.studentPoints, StudentPointsCompanion.insert(
          id: _id(payload),
          uuid: payload['uuid'] as String,
          studentId: _int(payload['student_id'])!,
          courseCircleId: Value(_int(payload['course_circle_id'])),
          attendanceSessionId: Value(_int(payload['attendance_session_id'])),
          points: _double(payload['points']) ?? 0,
          reason: payload['reason'] as String,
          note: Value(payload['note'] as String?),
          awardedOn: _date(payload['awarded_on'])!,
        ));
      default:
        return;
    }
  }

  /// upsert **مستهدِفاً `uuid` صراحةً** لا المفتاح الأساسي: `id` المحلي يُولَّد هنا
  /// ولا يأتي من الخادم، فالهدف الافتراضي (`id`) يجعل كل تحديثٍ إدراجاً يصطدم
  /// بقيد `unique(uuid)` بدل أن يحدّث الصفّ القائم.
  Future<void> _put<T extends Table, D>(
    TableInfo<T, D> table,
    Insertable<D> entity,
  ) {
    return _db.into(table).insert(
          entity,
          onConflict: DoUpdate(
            (_) => entity,
            target: [table.columnsByName['uuid']!],
          ),
        );
  }

  Future<void> _deleteByUuid(String tableName, String rowUuid) async {
    final table = _tableFor(tableName);

    if (table == null) {
      return;
    }

    await (_db.delete(table)
          ..where((t) => (t as dynamic).uuid.equals(rowUuid) as Expression<bool>))
        .go();
  }

  /// جدولُ drift المقابل لاسم الجدول الخادمي — و`null` لجدولٍ لا يُخزَّن محلياً
  /// (تصل صفوفُه لأن السحب معهدٌ كامل، ولا شاشة تقرؤها).
  TableInfo<Table, dynamic>? _tableFor(String tableName) {
    return switch (tableName) {
      'institutes' => _db.institutes,
      'courses' => _db.courses,
      'circles' => _db.circles,
      'shifts' => _db.shifts,
      'course_circles' => _db.courseCircles,
      'teachers' => _db.teachers,
      'course_circle_teachers' => _db.courseCircleTeachers,
      'students' => _db.students,
      'enrollments' => _db.enrollments,
      'attendance_sessions' => _db.attendanceSessions,
      'attendances' => _db.attendances,
      'memorization_logs' => _db.recitations,
      'absence_excuses' => _db.absenceExcusesTable,
      'student_points' => _db.studentPoints,
      _ => null,
    };
  }

  /// المفتاح الأساسي كما هو على الخادم — لا كما يولّده عدّاد drift.
  static Value<int> _id(Map<String, dynamic> payload) {
    final id = _int(payload['id']);

    return id == null ? const Value.absent() : Value(id);
  }

  /// عمودٌ عليه cast `'boolean'` يصل `true`/`false`؛ وبلا cast يصل `1`/`0`.
  static bool _bool(Object? value, {required bool orElse}) {
    if (value == null) return orElse;
    if (value is bool) return value;
    if (value is num) return value != 0;

    return value.toString() == '1' || value.toString() == 'true';
  }

  static int? _int(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static double? _double(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }

  /// عمودٌ عليه cast `'array'` يصل كائناً؛ فيُعاد ترميزه JSON لا `toString()` —
  /// الأخيرة تنتج صيغةَ Dart (`{a: b}`) التي لا يقرؤها `jsonDecode` لاحقاً.
  static String? _json(Object? value) {
    if (value == null) return null;
    if (value is String) return value;

    return jsonEncode(value);
  }
}
