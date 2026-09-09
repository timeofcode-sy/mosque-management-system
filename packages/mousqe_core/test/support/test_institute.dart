import 'package:drift/drift.dart';
import 'package:mousqe_core/mousqe_core.dart';

/// معهدٌ صغير مزروعٌ في drift مباشرةً — نظير `Tests\Concerns\BuildsInstitute`
/// الخادمي: دورةٌ جارية، دوامٌ يبدأ 08:00، حلقةٌ لأستاذنا وأخرى لغيره، وثلاثة طلاب.
///
/// الزرعُ مباشرٌ لا عبر [SyncPayloadApplier] قصداً: ما يُختبَر هنا هو استعلاماتُ
/// العرض وبناءُ الطابور، لا تحويلُ الحمولة (ولذلك اختبارُه في `mousqe_core`).
class TestInstitute {
  TestInstitute._(this.db);

  final AppDatabase db;

  static const teacherUuid = 'tch-me';
  static const otherTeacherUuid = 'tch-other';
  static const circleUuid = 'cc-1';
  static const otherCircleUuid = 'cc-2';

  /// حلقةٌ في الدورة الجارية **لم يُسنَد إليها أستاذٌ بعد** — بها يُختبَر أن كشف
  /// المشرف يراها (فهو من يسند إليها) وأن كشف الأستاذ لا يراه.
  static const unstaffedCircleUuid = 'cc-3';
  static const shiftStartsAt = '08:00:00';

  /// معرّفات الطلاب المحلية بترتيب الزرع.
  static const ali = 1;
  static const badr = 2;
  static const jamil = 3;

  static Future<TestInstitute> seed(AppDatabase db) async {
    final fixture = TestInstitute._(db);
    await fixture._write();

    return fixture;
  }

  Future<void> _write() async {
    await db
        .into(db.institutes)
        .insert(
          InstitutesCompanion.insert(
            id: const Value(1),
            uuid: 'ins-1',
            name: 'معهد النور',
          ),
        );

    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            id: const Value(1),
            uuid: 'crs-1',
            instituteId: 1,
            name: 'دورة 1447',
            startsOn: DateTime(2026, 9, 1),
            isCurrent: const Value(true),
          ),
        );

    // دورةٌ منتهية بحلقةٍ فيها — لا يجوز أن تظهر في «حلقاتي».
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            id: const Value(2),
            uuid: 'crs-0',
            instituteId: 1,
            name: 'دورة 1446',
            startsOn: DateTime(2025, 9, 1),
            isCurrent: const Value(false),
          ),
        );

    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            id: const Value(1),
            uuid: 'shf-1',
            courseId: 1,
            name: 'الدوام الصباحي',
            startsAt: shiftStartsAt,
            endsAt: '10:30:00',
          ),
        );

    await db
        .into(db.circles)
        .insert(
          CirclesCompanion.insert(
            id: const Value(1),
            uuid: 'crc-1',
            instituteId: 1,
            name: 'حلقة الفرقان',
          ),
        );

    await db
        .into(db.circles)
        .insert(
          CirclesCompanion.insert(
            id: const Value(2),
            uuid: 'crc-2',
            instituteId: 1,
            name: 'حلقة النهار',
          ),
        );

    await db
        .into(db.courseCircles)
        .insert(
          CourseCirclesCompanion.insert(
            id: const Value(1),
            uuid: circleUuid,
            courseId: 1,
            circleId: 1,
            shiftId: 1,
            room: const Value('قاعة 2'),
          ),
        );

    await db
        .into(db.courseCircles)
        .insert(
          CourseCirclesCompanion.insert(
            id: const Value(2),
            uuid: otherCircleUuid,
            courseId: 1,
            circleId: 2,
            shiftId: 1,
          ),
        );

    await db
        .into(db.circles)
        .insert(
          CirclesCompanion.insert(
            id: const Value(3),
            uuid: 'crc-3',
            instituteId: 1,
            name: 'حلقة العصر',
          ),
        );

    await db
        .into(db.courseCircles)
        .insert(
          CourseCirclesCompanion.insert(
            id: const Value(3),
            uuid: unstaffedCircleUuid,
            courseId: 1,
            circleId: 3,
            shiftId: 1,
          ),
        );

    await db
        .into(db.teachers)
        .insert(
          TeachersCompanion.insert(
            id: const Value(1),
            uuid: teacherUuid,
            instituteId: 1,
            displayName: 'أحمد بن سعيد',
          ),
        );

    await db
        .into(db.teachers)
        .insert(
          TeachersCompanion.insert(
            id: const Value(2),
            uuid: otherTeacherUuid,
            instituteId: 1,
            displayName: 'خالد بن عمر',
          ),
        );

    await db
        .into(db.courseCircleTeachers)
        .insert(
          CourseCircleTeachersCompanion.insert(
            id: const Value(1),
            uuid: 'cct-1',
            courseCircleId: 1,
            teacherId: 1,
          ),
        );

    await db
        .into(db.courseCircleTeachers)
        .insert(
          CourseCircleTeachersCompanion.insert(
            id: const Value(2),
            uuid: 'cct-2',
            courseCircleId: 2,
            teacherId: 2,
          ),
        );

    // أستاذٌ ثانٍ في حلقة الفرقان — بأستاذين تُختبَر **قاعدةُ عدم التكرار**: كشفُ
    // المشرف لا يعرض الحلقةَ مرّتين لأنها بأستاذين.
    await db
        .into(db.courseCircleTeachers)
        .insert(
          CourseCircleTeachersCompanion.insert(
            id: const Value(3),
            uuid: 'cct-3',
            courseCircleId: 1,
            teacherId: 2,
            role: const Value('assistant'),
          ),
        );

    await _student(ali, 'stu-ali', 'علي', 'حسن', 'الشامي');
    await _student(badr, 'stu-badr', 'بدر', 'سالم', 'الحلبي');
    await _student(jamil, 'stu-jamil', 'جميل', 'راشد', 'الدمشقي');

    // علي وبدر مسجَّلان منذ بداية الدورة، وجميل انضمّ في 09-10 — به يُختبَر أن
    // التفقّد الرجعي يرى الحلقة كما كانت يومَها.
    await _enrollment(1, 'enr-1', ali, DateTime(2026, 9, 1), null);
    await _enrollment(2, 'enr-2', badr, DateTime(2026, 9, 1), null);
    await _enrollment(3, 'enr-3', jamil, DateTime(2026, 9, 10), null);
  }

  Future<void> _student(
    int id,
    String uuid,
    String first,
    String father,
    String family,
  ) {
    return db
        .into(db.students)
        .insert(
          StudentsCompanion.insert(
            id: Value(id),
            uuid: uuid,
            instituteId: 1,
            firstName: first,
            fatherName: father,
            familyName: family,
          ),
        );
  }

  Future<void> _enrollment(
    int id,
    String uuid,
    int studentId,
    DateTime from,
    DateTime? to,
  ) {
    return db
        .into(db.enrollments)
        .insert(
          EnrollmentsCompanion.insert(
            id: Value(id),
            uuid: uuid,
            courseCircleId: 1,
            studentId: studentId,
            enrolledOn: Value(from),
            leftOn: Value(to),
          ),
        );
  }

  /// إذن غياب مقبول يغطّي [day] لـ[studentId].
  Future<void> approveExcuse(int studentId, DateTime day) {
    return db
        .into(db.absenceExcusesTable)
        .insert(
          AbsenceExcusesTableCompanion.insert(
            uuid: 'exc-$studentId-${day.day}',
            studentId: studentId,
            fromDate: day,
            toDate: day,
            reason: 'سفر عائلي',
            status: const Value('approved'),
          ),
        );
  }

  /// جلسةٌ وصلت من الخادم عبر `sync/pull`.
  Future<void> syncSession({
    required int id,
    required String uuid,
    required DateTime day,
    String status = 'draft',
    int courseCircleId = 1,
  }) {
    return db
        .into(db.attendanceSessions)
        .insert(
          AttendanceSessionsCompanion.insert(
            id: Value(id),
            uuid: uuid,
            courseCircleId: courseCircleId,
            sessionDate: day,
            status: Value(status),
          ),
        );
  }

  /// تسميعٌ وصل من الخادم بأسطره ونقاطه مجمَّدةً — هو من يحسبها لا العميل.
  Future<void> syncRecitation({
    required String uuid,
    required int studentId,
    required int sessionId,
    int fromSurah = 78,
    int fromAyah = 1,
    int toSurah = 78,
    int toAyah = 40,
    double points = 12.5,
  }) {
    return db
        .into(db.recitations)
        .insert(
          RecitationsCompanion.insert(
            uuid: uuid,
            studentId: studentId,
            courseCircleId: const Value(1),
            attendanceSessionId: Value(sessionId),
            date: DateTime(2026, 9, 15),
            grade: const Value('excellent'),
            fromSurah: Value(fromSurah),
            fromAyah: Value(fromAyah),
            toSurah: Value(toSurah),
            toAyah: Value(toAyah),
            juz: const Value(30),
            points: Value(points),
          ),
        );
  }

  /// تفقّدُ أستاذٍ وصل من الخادم — الجدولُ يُبثّ في `change_log` منذ م.4، ولم يكن
  /// له صفٌّ في drift حتى م.6.4.
  Future<void> syncTeacherAttendance({
    required String uuid,
    required int sessionId,
    required int teacherId,
    required String status,
    int? lateMinutes,
  }) {
    return db
        .into(db.teacherAttendances)
        .insert(
          TeacherAttendancesCompanion.insert(
            uuid: uuid,
            attendanceSessionId: sessionId,
            teacherId: teacherId,
            status: Value(status),
            lateMinutes: Value(lateMinutes),
            recordedAt: DateTime(2026, 9, 15, 8, 2),
          ),
        );
  }

  Future<void> syncAttendance({
    required String uuid,
    required int sessionId,
    required int studentId,
    required String status,
    int? lateMinutes,
    DateTime? recordedAt,
  }) {
    return db
        .into(db.attendances)
        .insert(
          AttendancesCompanion.insert(
            uuid: uuid,
            attendanceSessionId: sessionId,
            studentId: studentId,
            status: Value(status),
            lateMinutes: Value(lateMinutes),
            recordedAt: recordedAt ?? DateTime(2026, 9, 15, 8, 5),
          ),
        );
  }
}
