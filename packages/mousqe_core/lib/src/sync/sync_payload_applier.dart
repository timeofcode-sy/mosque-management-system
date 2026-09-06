import 'package:drift/drift.dart';

import '../db/database.dart';

/// يطبّق صفّاً واحداً من `change_log` على drift — [SYNC-PROTOCOL.md §8](../../../../docs/SYNC-PROTOCOL.md)
/// البند 6: `create`/`update` ⇒ `insertOnConflictUpdate` بمطابقة `uuid`، و`delete`
/// ⇒ حذف الصفّ بمطابقة `uuid` (الحمولة `null` في الحذف).
///
/// الحمولة خامة (`$model->toArray()`) لا شكل الـ API Resource — التحويل الوحيد
/// المطلوب هو JSON→drift row، لا إعادة تسمية حقول.
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
        final entity = InstitutesCompanion.insert(
          uuid: payload['uuid'] as String,
          name: payload['name'] as String,
          shortName: Value(payload['short_name'] as String?),
          logoPath: Value(payload['logo_path'] as String?),
          settings: Value(_encodeJson(payload['settings'])),
          isActive: Value((payload['is_active'] as int? ?? 1) == 1),
        );
        await _db.into(_db.institutes).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.institutes.uuid]),
            );
      case 'courses':
        final entity = CoursesCompanion.insert(
          uuid: payload['uuid'] as String,
          instituteId: payload['institute_id'] as int,
          name: payload['name'] as String,
          startsOn: DateTime.parse(payload['starts_on'] as String),
          endsOn: Value(_parseNullableDate(payload['ends_on'])),
          status: Value(payload['status'] as String? ?? 'draft'),
          isCurrent: Value((payload['is_current'] as int? ?? 0) == 1),
        );
        await _db.into(_db.courses).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.courses.uuid]),
            );
      case 'course_circles':
        final entity = CourseCirclesCompanion.insert(
          uuid: payload['uuid'] as String,
          courseId: payload['course_id'] as int,
          circleId: payload['circle_id'] as int,
          shiftId: payload['shift_id'] as int,
          room: Value(payload['room'] as String?),
          capacity: Value(payload['capacity'] as int?),
          status: Value(payload['status'] as String? ?? 'active'),
        );
        await _db.into(_db.courseCircles).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.courseCircles.uuid]),
            );
      case 'students':
        final entity = StudentsCompanion.insert(
          uuid: payload['uuid'] as String,
          instituteId: payload['institute_id'] as int,
          registrationNo: Value(payload['registration_no'] as String?),
          photoPath: Value(payload['photo_path'] as String?),
          firstName: payload['first_name'] as String,
          fatherName: payload['father_name'] as String,
          familyName: payload['family_name'] as String,
          status: Value(payload['status'] as String? ?? 'active'),
        );
        await _db.into(_db.students).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.students.uuid]),
            );
      case 'attendance_sessions':
        final entity = AttendanceSessionsCompanion.insert(
          uuid: payload['uuid'] as String,
          courseCircleId: payload['course_circle_id'] as int,
          sessionDate: DateTime.parse(payload['session_date'] as String),
          status: Value(payload['status'] as String? ?? 'draft'),
          completedAt: Value(_parseNullableDate(payload['completed_at'])),
        );
        await _db.into(_db.attendanceSessions).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.attendanceSessions.uuid]),
            );
      case 'attendances':
        final entity = AttendancesCompanion.insert(
          uuid: payload['uuid'] as String,
          attendanceSessionId: payload['attendance_session_id'] as int,
          studentId: payload['student_id'] as int,
          status: Value(payload['status'] as String? ?? 'present'),
          lateMinutes: Value(payload['late_minutes'] as int?),
          note: Value(payload['note'] as String?),
          notePolarity: Value(payload['note_polarity'] as String?),
          recordedAt: DateTime.parse(payload['recorded_at'] as String),
        );
        await _db.into(_db.attendances).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.attendances.uuid]),
            );
      case 'memorization_logs':
        final entity = RecitationsCompanion.insert(
          uuid: payload['uuid'] as String,
          studentId: payload['student_id'] as int,
          courseCircleId: Value(payload['course_circle_id'] as int?),
          attendanceSessionId: Value(payload['attendance_session_id'] as int?),
          curriculumItemId: Value(payload['curriculum_item_id'] as int?),
          date: DateTime.parse(payload['date'] as String),
          type: Value(payload['type'] as String? ?? 'hifz'),
          grade: Value(payload['grade'] as String?),
          fromSurah: Value(payload['from_surah'] as int?),
          fromAyah: Value(payload['from_ayah'] as int?),
          toSurah: Value(payload['to_surah'] as int?),
          toAyah: Value(payload['to_ayah'] as int?),
          lines: Value(_parseNullableDouble(payload['lines'])),
          newLines: Value(_parseNullableDouble(payload['new_lines'])),
          points: Value(_parseNullableDouble(payload['points']) ?? 0),
          juz: Value(payload['juz'] as int?),
          notes: Value(payload['notes'] as String?),
        );
        await _db.into(_db.recitations).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.recitations.uuid]),
            );
      case 'absence_excuses':
        final entity = AbsenceExcusesTableCompanion.insert(
          uuid: payload['uuid'] as String,
          studentId: payload['student_id'] as int,
          fromDate: DateTime.parse(payload['from_date'] as String),
          toDate: DateTime.parse(payload['to_date'] as String),
          reason: payload['reason'] as String,
          attachmentPath: Value(payload['attachment_path'] as String?),
          status: Value(payload['status'] as String? ?? 'pending'),
          reviewNote: Value(payload['review_note'] as String?),
        );
        await _db.into(_db.absenceExcusesTable).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.absenceExcusesTable.uuid]),
            );
      case 'student_points':
        final entity = StudentPointsCompanion.insert(
          uuid: payload['uuid'] as String,
          studentId: payload['student_id'] as int,
          courseCircleId: Value(payload['course_circle_id'] as int?),
          attendanceSessionId: Value(payload['attendance_session_id'] as int?),
          points: _parseNullableDouble(payload['points']) ?? 0,
          reason: payload['reason'] as String,
          note: Value(payload['note'] as String?),
          awardedOn: DateTime.parse(payload['awarded_on'] as String),
        );
        await _db.into(_db.studentPoints).insert(
              entity,
              onConflict: DoUpdate((_) => entity, target: [_db.studentPoints.uuid]),
            );
      default:
        return;
    }
  }

  Future<void> _deleteByUuid(String tableName, String rowUuid) async {
    switch (tableName) {
      case 'institutes':
        await (_db.delete(_db.institutes)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'courses':
        await (_db.delete(_db.courses)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'course_circles':
        await (_db.delete(_db.courseCircles)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'students':
        await (_db.delete(_db.students)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'attendance_sessions':
        await (_db.delete(_db.attendanceSessions)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'attendances':
        await (_db.delete(_db.attendances)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'memorization_logs':
        await (_db.delete(_db.recitations)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'absence_excuses':
        await (_db.delete(_db.absenceExcusesTable)..where((t) => t.uuid.equals(rowUuid))).go();
      case 'student_points':
        await (_db.delete(_db.studentPoints)..where((t) => t.uuid.equals(rowUuid))).go();
    }
  }

  String? _encodeJson(Object? value) => value == null ? null : value.toString();

  DateTime? _parseNullableDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  double? _parseNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
