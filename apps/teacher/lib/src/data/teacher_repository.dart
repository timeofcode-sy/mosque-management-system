import 'package:drift/drift.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:uuid/uuid.dart';

import 'views.dart';

/// كل قراءةٍ وكتابةٍ يحتاجها تطبيق الأستاذ، مجموعةً في مكانٍ واحد.
///
/// **القراءة من drift لا من الشبكة.** نقاطُ REST تُستدعى مرّتين فقط في عمر
/// الجلسة: `/auth/login` و`/bootstrap`. وما عدا ذلك يصل عبر `sync/pull` ويُقرأ
/// من المخزن المحلي، فيستوي عملُ التطبيق متّصلاً ومنقطعاً.
///
/// **والكتابة طابورٌ لا طلب.** كل فعلٍ يُترجَم إلى عملية `sync/push` تُثبَّت في
/// `pending_operations` **قبل** أي محاولة إرسال
/// ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 1).
class TeacherRepository {
  TeacherRepository({required AppDatabase db, required SyncEngine syncEngine})
    : _db = db,
      _syncEngine = syncEngine;

  final AppDatabase _db;

  final SyncEngine _syncEngine;

  static const _uuid = Uuid();

  // ---------------------------------------------------------------- الحلقات

  /// حلقات الأستاذ في الدورة الجارية.
  ///
  /// الترشيح صريحٌ بـ[teacherUuid] لا مفترَض: السحب معهدٌ كامل، فالجهاز يخزّن
  /// حلقاتٍ ليست له ([SYNC-PROTOCOL.md §4](../../../../../docs/SYNC-PROTOCOL.md)).
  Future<List<CircleView>> loadCircles(String teacherUuid) async {
    final query =
        _db.select(_db.courseCircles).join([
            innerJoin(
              _db.circles,
              _db.circles.id.equalsExp(_db.courseCircles.circleId),
            ),
            innerJoin(
              _db.shifts,
              _db.shifts.id.equalsExp(_db.courseCircles.shiftId),
            ),
            innerJoin(
              _db.courses,
              _db.courses.id.equalsExp(_db.courseCircles.courseId),
            ),
            innerJoin(
              _db.courseCircleTeachers,
              _db.courseCircleTeachers.courseCircleId.equalsExp(
                _db.courseCircles.id,
              ),
            ),
            innerJoin(
              _db.teachers,
              _db.teachers.id.equalsExp(_db.courseCircleTeachers.teacherId),
            ),
          ])
          ..where(
            _db.teachers.uuid.equals(teacherUuid) &
                _db.courses.isCurrent.equals(true),
          )
          ..orderBy([
            OrderingTerm.asc(_db.shifts.sortOrder),
            OrderingTerm.asc(_db.circles.name),
          ]);

    final rows = await query.get();
    final circles = <CircleView>[];

    for (final row in rows) {
      final courseCircle = row.readTable(_db.courseCircles);

      circles.add(
        CircleView(
          id: courseCircle.id,
          uuid: courseCircle.uuid,
          circleName: row.readTable(_db.circles).name,
          shiftName: row.readTable(_db.shifts).name,
          shiftStartsAt: row.readTable(_db.shifts).startsAt,
          room: courseCircle.room,
          capacity: courseCircle.capacity,
          status: courseCircle.status,
          studentsCount: await _activeEnrollmentCount(courseCircle.id),
        ),
      );
    }

    return circles;
  }

  Stream<List<CircleView>> watchCircles(String teacherUuid) =>
      _watch(() => loadCircles(teacherUuid));

  Future<int> _activeEnrollmentCount(int courseCircleId) async {
    final total = _db.enrollments.id.count();
    final row =
        await (_db.selectOnly(_db.enrollments)
              ..addColumns([total])
              ..where(
                _db.enrollments.courseCircleId.equals(courseCircleId) &
                    _db.enrollments.status.equals('active'),
              ))
            .getSingle();

    return row.read(total) ?? 0;
  }

  // ---------------------------------------------------------------- الجلسة

  /// كشفُ يومٍ واحد: المتزامنُ من الخادم، تعلوه مسودّةُ هذا الجهاز.
  Future<SessionView> loadSession({
    required CircleView circle,
    required DateTime date,
    required int graceMinutes,
  }) async {
    final day = _dateOnly(date);

    final session =
        await (_db.select(_db.attendanceSessions)..where(
              (t) =>
                  t.courseCircleId.equals(circle.id) &
                  t.sessionDate.equals(day),
            ))
            .getSingleOrNull();

    final local =
        await (_db.select(_db.localSessions)..where(
              (t) =>
                  t.courseCircleId.equals(circle.id) &
                  t.sessionDate.equals(day),
            ))
            .getSingleOrNull();

    final synced = session == null
        ? <int, AttendanceRow>{}
        : {
            for (final row in await (_db.select(
              _db.attendances,
            )..where((t) => t.attendanceSessionId.equals(session.id))).get())
              row.studentId: row,
          };

    final drafts = {
      for (final row
          in await (_db.select(_db.localAttendances)..where(
                (t) =>
                    t.courseCircleId.equals(circle.id) &
                    t.sessionDate.equals(day),
              ))
              .get())
        row.studentId: row,
    };

    final excused = await _excusedStudentIds(day);
    final roster = <RosterEntry>[];

    for (final enrollment in await _rosterOn(circle.id, day)) {
      final student = enrollment.$2;
      final draft = drafts[student.id];
      final confirmed = synced[student.id];

      if (draft != null) {
        roster.add(
          RosterEntry(
            studentId: student.id,
            studentUuid: student.uuid,
            fullName: _fullName(student),
            status: _status(draft.status),
            origin: AttendanceOrigin.pending,
            lateMinutes:
                draft.lateMinutes ??
                _computedLateMinutes(
                  circle,
                  day,
                  draft.recordedAt,
                  draft.status,
                  graceMinutes,
                ),
            lateMinutesOverride: draft.lateMinutes,
            note: draft.note,
            recordedAt: draft.recordedAt,
          ),
        );
        continue;
      }

      if (confirmed != null) {
        roster.add(
          RosterEntry(
            studentId: student.id,
            studentUuid: student.uuid,
            fullName: _fullName(student),
            status: _status(confirmed.status),
            origin: AttendanceOrigin.synced,
            lateMinutes: confirmed.lateMinutes,
            note: confirmed.note,
            recordedAt: confirmed.recordedAt,
          ),
        );
        continue;
      }

      // نظير الزرع الخادمي في OpenAttendanceSession: «حاضر» افتراضاً، و«مأذون»
      // لمن يغطّيه إذنٌ مقبول — قيمةٌ مقترحة تنتظر من يؤكّدها، لا تفقُّدٌ وقع.
      roster.add(
        RosterEntry(
          studentId: student.id,
          studentUuid: student.uuid,
          fullName: _fullName(student),
          status: excused.contains(student.id)
              ? AttendanceStatus.excused
              : AttendanceStatus.present,
          origin: AttendanceOrigin.suggested,
          lateMinutes: null,
          note: null,
          recordedAt: null,
        ),
      );
    }

    roster.sort((a, b) => a.fullName.compareTo(b.fullName));

    return SessionView(
      circle: circle,
      date: day,
      serverUuid: session?.uuid,
      localUuid: local?.uuid,
      status:
          session?.status ??
          (local == null ? null : (local.completed ? 'completed' : 'draft')),
      roster: roster,
    );
  }

  Stream<SessionView> watchSession({
    required CircleView circle,
    required DateTime date,
    required int graceMinutes,
  }) => _watch(
    () => loadSession(circle: circle, date: date, graceMinutes: graceMinutes),
  );

  /// التسجيلات القائمة في ذلك التاريخ — نقلٌ حرفي لشرطَي
  /// `OpenAttendanceSession::enrollmentsOn`، فالتفقّد الرجعي يرى الحلقة كما كانت يومَها.
  Future<List<(EnrollmentRow, StudentRow)>> _rosterOn(
    int courseCircleId,
    DateTime day,
  ) async {
    final query =
        _db.select(_db.enrollments).join([
          innerJoin(
            _db.students,
            _db.students.id.equalsExp(_db.enrollments.studentId),
          ),
        ])..where(
          _db.enrollments.courseCircleId.equals(courseCircleId) &
              (_db.enrollments.enrolledOn.isNull() |
                  _db.enrollments.enrolledOn.isSmallerOrEqualValue(day)) &
              (_db.enrollments.leftOn.isNull() |
                  _db.enrollments.leftOn.isBiggerOrEqualValue(day)),
        );

    return [
      for (final row in await query.get())
        (row.readTable(_db.enrollments), row.readTable(_db.students)),
    ];
  }

  Future<Set<int>> _excusedStudentIds(DateTime day) async {
    final rows =
        await (_db.select(_db.absenceExcusesTable)..where(
              (t) =>
                  t.status.equals('approved') &
                  t.fromDate.isSmallerOrEqualValue(day) &
                  t.toDate.isBiggerOrEqualValue(day),
            ))
            .get();

    return {for (final row in rows) row.studentId};
  }

  // ---------------------------------------------------------------- الكتابة

  /// يثبّت المسودّة محلياً ويصفّ عملياتها — بلا أي محاولة إرسال هنا.
  ///
  /// الترتيب في الطابور مقصود: `attendance.session.open` قبل `attendance.take`،
  /// وإلا فشلت الثانية بـ404 ([SYNC-PROTOCOL.md §3](../../../../../docs/SYNC-PROTOCOL.md) البند 3).
  Future<void> saveAttendance({
    required SessionView session,
    required List<RosterEntry> entries,
  }) async {
    final day = session.date;
    final circle = session.circle;
    final sessionUuid = session.serverUuid ?? session.localUuid ?? _uuid.v4();

    if (!session.exists) {
      await _db
          .into(_db.localSessions)
          .insertOnConflictUpdate(
            LocalSessionRow(
              courseCircleId: circle.id,
              sessionDate: day,
              uuid: sessionUuid,
              completed: false,
            ),
          );

      await _syncEngine.enqueue('attendance.session.open', {
        'uuid': sessionUuid,
        'course_circle_uuid': circle.uuid,
        'session_date': _isoDate(day),
      });
    }

    final changed = entries
        .where((entry) => entry.origin == AttendanceOrigin.pending)
        .toList();

    if (changed.isEmpty) {
      return;
    }

    await _db.batch((batch) {
      for (final entry in changed) {
        batch.insert(
          _db.localAttendances,
          LocalAttendanceRow(
            courseCircleId: circle.id,
            sessionDate: day,
            studentId: entry.studentId,
            status: entry.status.name,
            // القيمة المرسَلة صراحةً تغلب المحسوبة على الخادم، فلا تُرسَل إلا
            // حين يصحّحها الأستاذ بيده (§0 البند 2 · API.md §6).
            lateMinutes: entry.lateMinutesOverride,
            note: entry.note,
            recordedAt: entry.recordedAt ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    await _syncEngine.enqueue('attendance.take', {
      'session_uuid': sessionUuid,
      // المفتاح الطبيعي مرفقٌ دائماً: معرّفُنا المحلي قد لا يوجد على الخادم إن
      // سبقنا أحدٌ إلى فتح جلسة اليوم (SyncPush::attendanceSession).
      'course_circle_uuid': circle.uuid,
      'session_date': _isoDate(day),
      'attendances': [
        for (final entry in changed)
          {
            'student_uuid': entry.studentUuid,
            'status': entry.status.name,
            if (entry.lateMinutesOverride != null)
              'late_minutes': entry.lateMinutesOverride,
            if (entry.note != null && entry.note!.isNotEmpty)
              'note': entry.note,
            // زمنُ الجهاز وقت الحدث لا وقت الإرسال — به يحسم الخادم التعارض
            // (SYNC-PROTOCOL §8 البند 2).
            'recorded_at': (entry.recordedAt ?? DateTime.now())
                .toUtc()
                .toIso8601String(),
          },
      ],
    });
  }

  Future<void> completeSession(SessionView session) async {
    final sessionUuid = session.serverUuid ?? session.localUuid;

    if (sessionUuid == null) {
      return;
    }

    await _db
        .into(_db.localSessions)
        .insertOnConflictUpdate(
          LocalSessionRow(
            courseCircleId: session.circle.id,
            sessionDate: session.date,
            uuid: sessionUuid,
            completed: true,
          ),
        );

    await _syncEngine.enqueue('attendance.session.complete', {
      'session_uuid': sessionUuid,
      'course_circle_uuid': session.circle.uuid,
      'session_date': _isoDate(session.date),
    });
  }

  /// الأسطر والنقاط **لا تُحسب هنا**: الخادم يحسبها ويجمّدها وقت التسجيل
  /// ([API.md §6](../../../../../docs/API.md)).
  Future<void> saveRecitation({
    required SessionView session,
    required String studentUuid,
    required RecitationType type,
    required int fromSurah,
    required int fromAyah,
    required int toSurah,
    required int toAyah,
    RecitationGrade? grade,
    int? juz,
    String? notes,
  }) {
    return _syncEngine.enqueue('recitation.save', {
      'session_uuid': session.serverUuid ?? session.localUuid,
      'course_circle_uuid': session.circle.uuid,
      'session_date': _isoDate(session.date),
      'student_uuid': studentUuid,
      'recitation': {
        'type': type.name,
        'from_surah': fromSurah,
        'from_ayah': fromAyah,
        'to_surah': toSurah,
        'to_ayah': toAyah,
        if (grade != null) 'grade': _gradeValue(grade),
        'juz': ?juz,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> awardPoints({
    required String studentUuid,
    required double points,
    required PointsReason reason,
    String? note,
    SessionView? session,
  }) {
    return _syncEngine.enqueue('points.award', {
      'student_uuid': studentUuid,
      'points': points,
      'reason': reason.name,
      if (note != null && note.isNotEmpty) 'note': note,
      'awarded_on': _isoDate(DateTime.now()),
      if (session != null)
        'session_uuid': session.serverUuid ?? session.localUuid,
    });
  }

  /// تُستدعى بعد كل مزامنة ناجحة: طابورٌ فارغ يعني أن الخادم التزم بكل ما كتبناه
  /// وأن السحب أعاده إلينا مطبَّقاً — فلا تبقى للمسودّة وظيفة، وبقاؤها يعني
  /// عرضَ قيمةٍ محليّةٍ فوق قيمةٍ حسمها الخادم بخلافها.
  Future<void> clearSettledDrafts() async {
    final pending = await _db.select(_db.pendingOperations).get();

    if (pending.isNotEmpty) {
      return;
    }

    await _db.transaction(() async {
      await _db.delete(_db.localAttendances).go();
      await _db.delete(_db.localSessions).go();
    });
  }

  // ---------------------------------------------------------------- السجلّات

  /// سجل الجلسات — مرشَّحٌ بحلقات الأستاذ لا بكل ما وصل الجهاز.
  Future<List<SessionLogEntry>> loadSessionLog(String teacherUuid) async {
    final circles = await loadCircles(teacherUuid);

    if (circles.isEmpty) {
      return const [];
    }

    final byId = {for (final circle in circles) circle.id: circle};

    final sessions =
        await (_db.select(_db.attendanceSessions)
              ..where((t) => t.courseCircleId.isIn(byId.keys))
              ..orderBy([(t) => OrderingTerm.desc(t.sessionDate)]))
            .get();

    final log = <SessionLogEntry>[];

    for (final session in sessions) {
      final rows = await (_db.select(
        _db.attendances,
      )..where((t) => t.attendanceSessionId.equals(session.id))).get();

      int count(String status) =>
          rows.where((row) => row.status == status).length;

      log.add(
        SessionLogEntry(
          uuid: session.uuid,
          circleName: byId[session.courseCircleId]!.circleName,
          date: session.sessionDate,
          status: session.status,
          present: count('present'),
          absent: count('absent'),
          late: count('late'),
          excused: count('excused'),
        ),
      );
    }

    return log;
  }

  Stream<List<SessionLogEntry>> watchSessionLog(String teacherUuid) =>
      _watch(() => loadSessionLog(teacherUuid));

  Future<StudentProfile?> loadStudentProfile(int studentId) async {
    final student = await (_db.select(
      _db.students,
    )..where((t) => t.id.equals(studentId))).getSingleOrNull();

    if (student == null) {
      return null;
    }

    final attendances =
        await (_db.select(_db.attendances)
              ..where((t) => t.studentId.equals(studentId))
              ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
            .get();

    final sessions = {
      for (final row in await _db.select(_db.attendanceSessions).get())
        row.id: row,
    };

    return StudentProfile(
      studentId: student.id,
      uuid: student.uuid,
      fullName: _fullName(student),
      registrationNo: student.registrationNo,
      attendance: [
        for (final row in attendances)
          StudentAttendanceEntry(
            date:
                sessions[row.attendanceSessionId]?.sessionDate ??
                row.recordedAt,
            status: _status(row.status),
            lateMinutes: row.lateMinutes,
            note: row.note,
          ),
      ],
      recitations:
          await (_db.select(_db.recitations)
                ..where((t) => t.studentId.equals(studentId))
                ..orderBy([(t) => OrderingTerm.desc(t.date)]))
              .get(),
      points:
          await (_db.select(_db.studentPoints)
                ..where((t) => t.studentId.equals(studentId))
                ..orderBy([(t) => OrderingTerm.desc(t.awardedOn)]))
              .get(),
    );
  }

  Stream<StudentProfile?> watchStudentProfile(int studentId) =>
      _watch(() => loadStudentProfile(studentId));

  // ---------------------------------------------------------------- أدوات

  /// تتبُّعٌ عامّ: أعِد بناء العرض على كل تغيّرٍ في المخزن.
  ///
  /// استعلاماتُ هذه الشاشات تلمس خمسة جداول أو ستة، ولا يُبنى أيٌّ منها من
  /// `select` واحد يتتبّعه drift وحده. فالتغيير هو الإشارة، والقراءةُ كاملةٌ
  /// بعده — رخيصةٌ على حجمٍ متوقَّعه ≤٢٠ حلقة × ≤٢٠ طالباً ([PLAN.md §13](../../../../../docs/PLAN.md)).
  Stream<T> _watch<T>(Future<T> Function() read) async* {
    yield await read();

    await for (final _ in _db.tableUpdates()) {
      yield await read();
    }
  }

  int? _computedLateMinutes(
    CircleView circle,
    DateTime day,
    DateTime recordedAt,
    String status,
    int graceMinutes,
  ) {
    if (status != AttendanceStatus.late.name) {
      return null;
    }

    return LateMinutes.afterGrace(
      LateMinutes.forSession(
        shiftStartsAt: circle.shiftStartsAt,
        sessionDate: day,
        recordedAt: recordedAt,
      ),
      graceMinutes,
    );
  }

  static String _fullName(StudentRow student) =>
      '${student.firstName} ${student.fatherName} ${student.familyName}'.trim();

  static AttendanceStatus _status(String value) =>
      AttendanceStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => AttendanceStatus.present,
      );

  /// `RecitationGrade.veryGood` ⇒ `very_good` — الخادم يقرأ snake_case.
  static String _gradeValue(RecitationGrade grade) =>
      grade == RecitationGrade.veryGood ? 'very_good' : grade.name;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
