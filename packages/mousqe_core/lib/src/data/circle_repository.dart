import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../models/enums.dart';
import '../support/late_minutes.dart';
import '../sync/sync_engine.dart';
import 'circle_views.dart';

/// كل قراءةٍ وكتابةٍ في عمل الحلقة — تفقّداً وتسميعاً ونقاطاً وسجلّاً — مجموعةً في
/// مكانٍ واحد يستدعيه **السطحان**: تطبيقُ الأستاذ وديسكتوبُ المشرف.
///
/// **القراءة من drift لا من الشبكة.** نقاطُ REST تُستدعى مرّتين فقط في عمر
/// الجلسة: `/auth/login` و`/bootstrap`. وما عدا ذلك يصل عبر `sync/pull` ويُقرأ
/// من المخزن المحلي، فيستوي عملُ التطبيق متّصلاً ومنقطعاً.
///
/// **والكتابة طابورٌ لا طلب.** كل فعلٍ يُترجَم إلى عملية `sync/push` تُثبَّت في
/// `pending_operations` **قبل** أي محاولة إرسال
/// ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 1).
///
/// ### 🔑 م.6.4: رُفع من `apps/teacher/` ولم يُنسخ إليه
///
/// كان `TeacherRepository` في تطبيق الأستاذ، فلمّا احتاجه الديسكتوبُ رُفع إلى هنا
/// بحسب القرار 4 في [PHASE-6-STAGES.MD §0](../../../../../docs/PHASE-6-STAGES.MD):
/// «ما يُعاد استخدامه يُرفع إلى `packages/` حين يحتاجه الاثنان». وما تغيّر في
/// الرفع **ثلاثةُ فروقٍ بين السطحين، كلُّها معاملٌ لا فرعٌ في الشيفرة**:
///
/// 1. **الترشيح** — `teacherUuid` صار اختيارياً: الأستاذُ يمرّر معرّفه فيرى
///    حلقاتِه، والديسكتوبُ يتركه فارغاً فيرى حلقاتِ المعهد كلَّها. والجهازان
///    يخزّنان الشيءَ نفسَه أصلاً — السحبُ معهدٌ كامل
///    ([SYNC-PROTOCOL.md §4](../../../../../docs/SYNC-PROTOCOL.md)).
/// 2. **سلطةُ التصحيح** — `amend` في [saveAttendance]، و[SessionView.editableBy]
///    تقرأ `attendance.amend` من اللقطة بدل أن تُحرَّم الجلسةُ المكتملة على
///    الجميع. فالأستاذُ لا يعدّلها لأنه **لا يملك الصلاحية** لا لأن الشيفرة
///    تمنعه، وهو الفرق نفسُه الذي يحرسه الخادم في `SyncPush::assertPermitted`.
/// 3. **[lockSession] و[saveTeacherAttendance]** — بابان لا يفتحهما الأستاذ.
class CircleRepository {
  CircleRepository({required AppDatabase db, required SyncEngine syncEngine})
    : _db = db,
      _syncEngine = syncEngine;

  final AppDatabase _db;

  final SyncEngine _syncEngine;

  static const _uuid = Uuid();

  // ---------------------------------------------------------------- الحلقات

  /// حلقات الدورة الجارية — كلُّها، أو حلقاتُ [teacherUuid] وحده.
  ///
  /// الترشيح صريحٌ لا مفترَض: السحب معهدٌ كامل، فالجهاز يخزّن حلقاتٍ ليست لصاحبه
  /// ([SYNC-PROTOCOL.md §4](../../../../../docs/SYNC-PROTOCOL.md)). وتركُه فارغاً
  /// هو **حالةُ الديسكتوب**: المشرفُ يتفقّد أيَّ حلقةٍ في معهده لا حلقاتِه هو.
  Future<List<CircleView>> loadCircles([String? teacherUuid]) async {
    // وصلُ الأستاذ يُقحَم للترشيح وحده. ولو بقي دائماً لَكلّف كشفَ المشرف ثمنين:
    // حلقةٌ بأستاذين تظهر مرّتين، وحلقةٌ لم يُسنَد إليها أستاذٌ بعد لا تظهر أصلاً —
    // وهي أوّلُ ما يعنيه، فهو من يسند إليها.
    final query = _db.select(_db.courseCircles).join([
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
      if (teacherUuid != null) ...[
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
      ],
    ]);

    query
      ..where(
        teacherUuid == null
            ? _db.courses.isCurrent.equals(true)
            : _db.teachers.uuid.equals(teacherUuid) &
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
          teachers: await loadCircleTeachers(courseCircle.id),
        ),
      );
    }

    return circles;
  }

  Stream<List<CircleView>> watchCircles([String? teacherUuid]) =>
      _watch(() => loadCircles(teacherUuid));

  /// أساتذةُ الحلقة — يعرضهم كشفُ المشرف، وهم كشفُ **تفقّد الأساتذة** نفسُه.
  Future<List<TeacherView>> loadCircleTeachers(int courseCircleId) async {
    final query =
        _db.select(_db.courseCircleTeachers).join([
            innerJoin(
              _db.teachers,
              _db.teachers.id.equalsExp(_db.courseCircleTeachers.teacherId),
            ),
          ])
          ..where(
            _db.courseCircleTeachers.courseCircleId.equals(courseCircleId),
          )
          ..orderBy([OrderingTerm.asc(_db.teachers.displayName)]);

    return [
      for (final row in await query.get())
        TeacherView(
          id: row.readTable(_db.teachers).id,
          uuid: row.readTable(_db.teachers).uuid,
          fullName: row.readTable(_db.teachers).displayName,
          role: row.readTable(_db.courseCircleTeachers).role,
        ),
    ];
  }

  /// حالةُ جلسةِ يومٍ واحد لكل حلقة — مفهرسةً بمعرّف الحلقة، وغيابُ المفتاح يعني
  /// **لم تُفتح بعد**.
  ///
  /// استعلامان لا استعلامٌ لكل حلقة: شاشةُ التفقّد تعرض عشرين حلقة، وقراءةُ
  /// جلسةٍ كاملةٍ لكلٍّ منها لِتُعرَف حالتُها وحدَها كانت تلمس خمسة جداول عشرين
  /// مرّة. والمسودّةُ المحلية تعلو المتزامن كما في [loadSession].
  Future<Map<int, String>> loadDayStatuses(DateTime date) async {
    final day = _dateOnly(date);

    final statuses = {
      for (final row
          in await (_db.select(
            _db.attendanceSessions,
          )..where((t) => t.sessionDate.equals(day))).get())
        row.courseCircleId: row.status,
    };

    for (final row in await (_db.select(
      _db.localSessions,
    )..where((t) => t.sessionDate.equals(day))).get()) {
      final local = row.locked
          ? 'locked'
          : (row.completed ? 'completed' : 'draft');

      // المحليُّ يعلو المتزامن حين يكون **أبعدَ في الطريق**: مسوّدةٌ محلية فوق
      // جلسةٍ أقفلها غيرُنا ليست تحديثاً بل تخلّفاً عن دورة سحبٍ لم تصل.
      final rank = {'draft': 0, 'completed': 1, 'locked': 2};

      if ((rank[local] ?? 0) >= (rank[statuses[row.courseCircleId]] ?? -1)) {
        statuses[row.courseCircleId] = local;
      }
    }

    return statuses;
  }

  Stream<Map<int, String>> watchDayStatuses(DateTime date) =>
      _watch(() => loadDayStatuses(date));

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
    bool withTeachers = false,
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
    final recitations = await _recitationsOf(circle, day, session?.id);
    final points = await _pointsOf(circle, day, session?.id);
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
            recitations: recitations[student.id] ?? const [],
            points: points[student.id] ?? const [],
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
            recitations: recitations[student.id] ?? const [],
            points: points[student.id] ?? const [],
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
          recitations: recitations[student.id] ?? const [],
          points: points[student.id] ?? const [],
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
      // القفلُ المحلي يعلو حالةَ الخادم لأنه **أحدثُ منها دائماً**: صاحبُ الجهاز
      // هو من ضغط، ودورةُ السحب التي تؤكّده لم تصل بعد. والعكسُ ليس صحيحاً —
      // جلسةٌ قفلها غيرُه تصل مقفلةً في `attendance_sessions` بلا مسودّة.
      status: switch ((session?.status, local)) {
        (final String status, final local?) when local.locked && status != 'locked' => 'locked',
        (final String status, _) => status,
        (null, final local?) => local.locked
            ? 'locked'
            : (local.completed ? 'completed' : 'draft'),
        (null, null) => null,
      },
      roster: roster,
      teacherRoster: withTeachers
          ? await _teacherRoster(circle, day, session?.id)
          : const [],
    );
  }

  Stream<SessionView> watchSession({
    required CircleView circle,
    required DateTime date,
    required int graceMinutes,
    bool withTeachers = false,
  }) => _watch(
    () => loadSession(
      circle: circle,
      date: date,
      graceMinutes: graceMinutes,
      withTeachers: withTeachers,
    ),
  );

  /// كشفُ الأساتذة: المتزامنُ من الخادم، تعلوه مسودّةُ هذا الجهاز — بنفس قاعدة
  /// غلبة [loadSession] للطلاب.
  ///
  /// والأستاذُ الذي لم يُسجَّل له شيء يظهر بـ`recorded: false`: صفٌّ في النموذج
  /// ينتظر من يملؤه، لا حضورٌ مفترَض. وهذا خلافُ الطالب عمداً — الخادمُ يزرع
  /// صفوفَ الطلاب «حاضر» عند فتح الجلسة ولا يزرع للأساتذة شيئاً، فادّعاءُ حضورٍ
  /// لم يقله أحد كان سيجعل غيابَ الأستاذ **حضوراً بالسكوت**.
  Future<List<TeacherRosterEntry>> _teacherRoster(
    CircleView circle,
    DateTime day,
    int? sessionId,
  ) async {
    final teachers = circle.teachers.isNotEmpty
        ? circle.teachers
        : await loadCircleTeachers(circle.id);

    final synced = sessionId == null
        ? <int, TeacherAttendanceRow>{}
        : {
            for (final row in await (_db.select(
              _db.teacherAttendances,
            )..where((t) => t.attendanceSessionId.equals(sessionId))).get())
              row.teacherId: row,
          };

    final drafts = {
      for (final row
          in await (_db.select(_db.localTeacherAttendances)..where(
                (t) =>
                    t.courseCircleId.equals(circle.id) &
                    t.sessionDate.equals(day),
              ))
              .get())
        row.teacherId: row,
    };

    return [
      for (final teacher in teachers)
        if (drafts[teacher.id] case final draft?)
          TeacherRosterEntry(
            teacherId: teacher.id,
            teacherUuid: teacher.uuid,
            fullName: teacher.fullName,
            roleLabel: teacher.roleLabel,
            status: _status(draft.status),
            recorded: true,
            pending: true,
            lateMinutes: draft.lateMinutes,
            note: draft.note,
          )
        else if (synced[teacher.id] case final row?)
          TeacherRosterEntry(
            teacherId: teacher.id,
            teacherUuid: teacher.uuid,
            fullName: teacher.fullName,
            roleLabel: teacher.roleLabel,
            status: _status(row.status),
            recorded: true,
            pending: false,
            lateMinutes: row.lateMinutes,
            note: row.note,
          )
        else
          TeacherRosterEntry(
            teacherId: teacher.id,
            teacherUuid: teacher.uuid,
            fullName: teacher.fullName,
            roleLabel: teacher.roleLabel,
            status: AttendanceStatus.present,
            recorded: false,
            pending: false,
          ),
    ];
  }

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

  /// تسميعات الجلسة مفهرسةً بالطالب: المتزامنُ من الخادم، تعلوه مسودّةُ هذا الجهاز.
  ///
  /// المسودّة تغلب المتزامن بمطابقة [uuid] — وهو معرّفٌ **واحد** على الجانبين لأن
  /// العميل من يولّده. فتصحيحٌ لم يُدفَع بعد يُرى مصحَّحاً، والمحذوفُ لا يُرى.
  Future<Map<int, List<RecitationEntry>>> _recitationsOf(
    CircleView circle,
    DateTime day,
    int? sessionId,
  ) async {
    final synced = sessionId == null
        ? <RecitationRow>[]
        : await (_db.select(_db.recitations)
                ..where((t) => t.attendanceSessionId.equals(sessionId))
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get();

    final drafts =
        await (_db.select(_db.localRecitations)..where(
              (t) =>
                  t.courseCircleId.equals(circle.id) &
                  t.sessionDate.equals(day),
            ))
            .get();

    final draftsByUuid = {for (final row in drafts) row.uuid: row};
    final byStudent = <int, List<RecitationEntry>>{};

    void add(int studentId, RecitationEntry entry) =>
        byStudent.putIfAbsent(studentId, () => []).add(entry);

    for (final row in synced) {
      final draft = draftsByUuid.remove(row.uuid);

      if (draft != null) {
        if (!draft.deleted) {
          add(draft.studentId, _draftRecitation(draft));
        }
        continue;
      }

      add(
        row.studentId,
        RecitationEntry(
          uuid: row.uuid,
          type: _recitationType(row.type),
          grade: _recitationGrade(row.grade),
          fromSurah: row.fromSurah ?? 1,
          fromAyah: row.fromAyah ?? 1,
          toSurah: row.toSurah ?? row.fromSurah ?? 1,
          toAyah: row.toAyah ?? row.fromAyah ?? 1,
          juz: row.juz,
          notes: row.notes,
          points: row.points,
          pending: false,
        ),
      );
    }

    // ما بقي من المسودّات لم يصل الخادمَ بعد — تسميعاتٌ جديدة، أو حذفٌ لصفٍّ
    // لم يُسحب أصلاً فلا شيء يُعرض له.
    for (final draft in draftsByUuid.values.where((row) => !row.deleted)) {
      add(draft.studentId, _draftRecitation(draft));
    }

    return byStudent;
  }

  /// نقاط الجلسة مفهرسةً بالطالب — نظير [_recitationsOf] وبنفس قاعدة الغلبة.
  Future<Map<int, List<PointEntry>>> _pointsOf(
    CircleView circle,
    DateTime day,
    int? sessionId,
  ) async {
    // منحةٌ مُنحت قبل فتح الجلسة تُسجَّل بلا جلسة وتبقى صالحة (API.md §6)، فلو
    // رُشّحت بالجلسة وحدها لَاختفت من الشاشة فور مزامنتها — وهي نُسبت إلى يومها
    // وحلقتها، فبهما تُلتقط.
    final synced =
        await (_db.select(_db.studentPoints)
              ..where(
                (t) =>
                    (sessionId == null
                        ? const Constant(false)
                        : t.attendanceSessionId.equals(sessionId)) |
                    (t.attendanceSessionId.isNull() &
                        t.courseCircleId.equals(circle.id) &
                        t.awardedOn.equals(day)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();

    final drafts =
        await (_db.select(_db.localPoints)..where(
              (t) =>
                  t.courseCircleId.equals(circle.id) &
                  t.sessionDate.equals(day),
            ))
            .get();

    final draftsByUuid = {for (final row in drafts) row.uuid: row};
    final byStudent = <int, List<PointEntry>>{};

    void add(int studentId, PointEntry entry) =>
        byStudent.putIfAbsent(studentId, () => []).add(entry);

    for (final row in synced) {
      final draft = draftsByUuid.remove(row.uuid);

      if (draft != null) {
        if (!draft.deleted) {
          add(draft.studentId, _draftPoint(draft));
        }
        continue;
      }

      add(
        row.studentId,
        PointEntry(
          uuid: row.uuid,
          points: row.points,
          reason: _pointsReason(row.reason),
          note: row.note,
          pending: false,
        ),
      );
    }

    for (final draft in draftsByUuid.values.where((row) => !row.deleted)) {
      add(draft.studentId, _draftPoint(draft));
    }

    return byStudent;
  }

  static RecitationEntry _draftRecitation(LocalRecitationRow row) {
    return RecitationEntry(
      uuid: row.uuid,
      type: _recitationType(row.type),
      grade: _recitationGrade(row.grade),
      fromSurah: row.fromSurah,
      fromAyah: row.fromAyah,
      toSurah: row.toSurah,
      toAyah: row.toAyah,
      juz: row.juz,
      notes: row.notes,
      // لا نقاط لمسودّة: الخادم يحسبها ويجمّدها، وعرضُ صفرٍ مكانها كذبٌ لا انتظار.
      points: null,
      pending: true,
    );
  }

  static PointEntry _draftPoint(LocalPointRow row) {
    return PointEntry(
      uuid: row.uuid,
      points: row.points,
      reason: _pointsReason(row.reason),
      note: row.note,
      pending: true,
    );
  }

  // ---------------------------------------------------------------- الكتابة

  /// يثبّت المسودّة محلياً ويصفّ عملياتها — بلا أي محاولة إرسال هنا.
  ///
  /// الترتيب في الطابور مقصود: `attendance.session.open` قبل `attendance.take`،
  /// وإلا فشلت الثانية بـ404 ([SYNC-PROTOCOL.md §3](../../../../../docs/SYNC-PROTOCOL.md) البند 3).
  Future<void> saveAttendance({
    required SessionView session,
    required List<RosterEntry> entries,
    bool amend = false,
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
              locked: false,
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
      // التصحيحُ الرجعي يُعلَن في الحمولة لا يُستنتَج من حالة الخادم: هو ما يقرؤه
      // `SyncPush::assertPermitted` ليطلب `attendance.amend`، وما يمرّره
      // `TakeAttendance` ليتجاوز حارسَ الجلسة المكتملة (API.md §6).
      if (amend) 'amend': true,
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
            locked: session.locked,
          ),
        );

    await _syncEngine.enqueue('attendance.session.complete', {
      'session_uuid': sessionUuid,
      'course_circle_uuid': session.circle.uuid,
      'session_date': _isoDate(session.date),
    });
  }

  /// القفلُ النهائي — بعده لا تعديلَ ولا إعادةَ فتح، ولا يفعله إلا حاملُ
  /// `attendance.lock` (م.6.4).
  ///
  /// و**يُكمل قبل أن يقفل** إن كانت الجلسةُ مسودّة: `LockAttendanceSession` لا
  /// يقبل غيرَ المكتملة، فالعمليتان تُصفّان معاً بترتيبهما بدل أن تُعزَل الثانيةُ
  /// برسالة «لا تُقفل إلا الجلسة المكتملة» بعد ساعات. وهو نفسُ ترتيب
  /// `attendance.session.open` قبل `attendance.take`
  /// ([SYNC-PROTOCOL.md §3](../../../../../docs/SYNC-PROTOCOL.md) البند 3).
  Future<void> lockSession(SessionView session) async {
    final sessionUuid = session.serverUuid ?? session.localUuid;

    if (sessionUuid == null || session.locked) {
      return;
    }

    if (!session.completed) {
      await completeSession(session);
    }

    await _db
        .into(_db.localSessions)
        .insertOnConflictUpdate(
          LocalSessionRow(
            courseCircleId: session.circle.id,
            sessionDate: session.date,
            uuid: sessionUuid,
            completed: true,
            locked: true,
          ),
        );

    await _syncEngine.enqueue('attendance.session.lock', {
      'session_uuid': sessionUuid,
      'course_circle_uuid': session.circle.uuid,
      'session_date': _isoDate(session.date),
    });
  }

  /// تفقّدُ الأساتذة — صفوفُه منفصلةٌ عن صفوف الطلاب لأنها لا تدخل في نسبة الحلقة
  /// ولا ترتيبِها، تماماً كما فصلها `TakeTeacherAttendance` على الخادم.
  ///
  /// وبلا `recorded_at`: العقدُ لا يحمله ([API.md §6](../../../../../docs/API.md))،
  /// فلا حسمَ تعارضٍ لهذه الصفوف — آخرُ من كتب يغلب.
  Future<void> saveTeacherAttendance({
    required SessionView session,
    required List<TeacherRosterEntry> entries,
  }) async {
    final changed = entries.where((entry) => entry.pending).toList();

    if (changed.isEmpty) {
      return;
    }

    final sessionUuid = session.serverUuid ?? session.localUuid;

    if (sessionUuid == null) {
      return;
    }

    await _db.batch((batch) {
      for (final entry in changed) {
        batch.insert(
          _db.localTeacherAttendances,
          LocalTeacherAttendanceRow(
            courseCircleId: session.circle.id,
            sessionDate: session.date,
            teacherId: entry.teacherId,
            status: entry.status.name,
            lateMinutes: entry.lateMinutes,
            note: entry.note,
            recordedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    await _syncEngine.enqueue('attendance.teacher.take', {
      'session_uuid': sessionUuid,
      'course_circle_uuid': session.circle.uuid,
      'session_date': _isoDate(session.date),
      'teacher_attendances': [
        for (final entry in changed)
          {
            'teacher_uuid': entry.teacherUuid,
            'status': entry.status.name,
            if (entry.lateMinutes != null) 'late_minutes': entry.lateMinutes,
            if (entry.note != null && entry.note!.isNotEmpty)
              'note': entry.note,
          },
      ],
    });
  }

  /// الأسطر والنقاط **لا تُحسب هنا**: الخادم يحسبها ويجمّدها وقت التسجيل
  /// ([API.md §6](../../../../../docs/API.md)).
  ///
  /// و[uuid] فارغاً يعني تسميعاً جديداً يولّد هذا الجهاز معرّفه؛ ومملوءاً يعني
  /// تصحيحَ تسميعٍ قائم بإعادة إرساله بنفس المعرّف. الحالتان عمليةٌ واحدة على
  /// السلك (`recitation.save`)، والخادم يفرّق بينهما بالمعرّف وحده.
  Future<void> saveRecitation({
    required SessionView session,
    required int studentId,
    required String studentUuid,
    required RecitationType type,
    required int fromSurah,
    required int fromAyah,
    required int toSurah,
    required int toAyah,
    RecitationGrade? grade,
    int? juz,
    String? notes,
    String? uuid,
  }) async {
    final rowUuid = uuid ?? _uuid.v4();
    final trimmed = notes?.trim();

    await _db
        .into(_db.localRecitations)
        .insertOnConflictUpdate(
          LocalRecitationRow(
            uuid: rowUuid,
            studentId: studentId,
            courseCircleId: session.circle.id,
            sessionDate: session.date,
            type: type.name,
            grade: grade == null ? null : _gradeValue(grade),
            fromSurah: fromSurah,
            fromAyah: fromAyah,
            toSurah: toSurah,
            toAyah: toAyah,
            juz: juz,
            notes: trimmed == null || trimmed.isEmpty ? null : trimmed,
            deleted: false,
            recordedAt: DateTime.now(),
          ),
        );

    await _syncEngine.enqueue('recitation.save', {
      'session_uuid': session.serverUuid ?? session.localUuid,
      'course_circle_uuid': session.circle.uuid,
      'session_date': _isoDate(session.date),
      'student_uuid': studentUuid,
      'recitation': {
        'uuid': rowUuid,
        'type': type.name,
        'from_surah': fromSurah,
        'from_ayah': fromAyah,
        'to_surah': toSurah,
        'to_ayah': toAyah,
        if (grade != null) 'grade': _gradeValue(grade),
        'juz': ?juz,
        if (trimmed != null && trimmed.isNotEmpty) 'notes': trimmed,
      },
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// حذفُ تسميع: شاهدةٌ محلية تُخفيه فوراً، وعمليةٌ تُنفّذ الحذف على الخادم.
  ///
  /// الشاهدة ليست ترفاً: بدونها يبقى الصفُّ المتزامن ظاهراً بين ضغطة الحذف
  /// ونجاح الدفع — وقد تكون ساعات على جهازٍ بلا شبكة.
  Future<void> deleteRecitation({
    required SessionView session,
    required int studentId,
    required RecitationEntry recitation,
  }) async {
    await _db
        .into(_db.localRecitations)
        .insertOnConflictUpdate(
          LocalRecitationRow(
            uuid: recitation.uuid,
            studentId: studentId,
            courseCircleId: session.circle.id,
            sessionDate: session.date,
            type: recitation.type.name,
            grade: recitation.grade == null
                ? null
                : _gradeValue(recitation.grade!),
            fromSurah: recitation.fromSurah,
            fromAyah: recitation.fromAyah,
            toSurah: recitation.toSurah,
            toAyah: recitation.toAyah,
            juz: recitation.juz,
            notes: recitation.notes,
            deleted: true,
            recordedAt: DateTime.now(),
          ),
        );

    await _syncEngine.enqueue('recitation.delete', {
      'recitation_uuid': recitation.uuid,
    });
  }

  /// [uuid] كنظيره في [saveRecitation]: فارغاً منحةٌ جديدة، ومملوءاً تصحيحُ منحة.
  Future<void> awardPoints({
    required int studentId,
    required String studentUuid,
    required double points,
    required PointsReason reason,
    required SessionView session,
    String? note,
    String? uuid,
    bool linkToSession = true,
  }) async {
    final rowUuid = uuid ?? _uuid.v4();
    final trimmed = note?.trim();

    await _db
        .into(_db.localPoints)
        .insertOnConflictUpdate(
          LocalPointRow(
            uuid: rowUuid,
            studentId: studentId,
            courseCircleId: session.circle.id,
            sessionDate: session.date,
            points: points,
            reason: reason.name,
            note: trimmed == null || trimmed.isEmpty ? null : trimmed,
            deleted: false,
            recordedAt: DateTime.now(),
          ),
        );

    await _syncEngine.enqueue('points.award', {
      'uuid': rowUuid,
      'student_uuid': studentUuid,
      'points': points,
      'reason': reason.name,
      if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
      'awarded_on': _isoDate(session.date),
      // تُربط بالجلسة إن كانت مفتوحة، وتبقى صالحةً بدونها.
      if (linkToSession) ...{
        'session_uuid': session.serverUuid ?? session.localUuid,
        'course_circle_uuid': session.circle.uuid,
        'session_date': _isoDate(session.date),
      },
    });
  }

  Future<void> deletePoints({
    required SessionView session,
    required int studentId,
    required PointEntry award,
  }) async {
    await _db
        .into(_db.localPoints)
        .insertOnConflictUpdate(
          LocalPointRow(
            uuid: award.uuid,
            studentId: studentId,
            courseCircleId: session.circle.id,
            sessionDate: session.date,
            points: award.points,
            reason: award.reason.name,
            note: award.note,
            deleted: true,
            recordedAt: DateTime.now(),
          ),
        );

    await _syncEngine.enqueue('points.delete', {'point_uuid': award.uuid});
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
      await _db.delete(_db.localRecitations).go();
      await _db.delete(_db.localPoints).go();
    });
  }

  // ---------------------------------------------------------------- السجلّات

  /// سجلُّ الجلسات — مرشَّحٌ بحلقات [teacherUuid]، أو بحلقات المعهد كلِّها.
  ///
  /// والترشيحُ صريحٌ في الحالتين: `sync/pull` يجلب معهداً كاملاً، فالجهاز يخزّن
  /// جلساتِ حلقاتٍ ليست لصاحبه
  /// ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 7).
  Future<List<SessionLogEntry>> loadSessionLog([String? teacherUuid]) async {
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

  Stream<List<SessionLogEntry>> watchSessionLog([String? teacherUuid]) =>
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

  /// `very_good` ⇒ `RecitationGrade.veryGood` — عكسُ [_gradeValue]، و`null` لتسميعٍ
  /// بلا تقدير (وهو خيارٌ صريح في النموذج لا قيمةٌ ناقصة).
  static RecitationGrade? _recitationGrade(String? value) => switch (value) {
    'excellent' => RecitationGrade.excellent,
    'very_good' => RecitationGrade.veryGood,
    'good' => RecitationGrade.good,
    _ => null,
  };

  static RecitationType _recitationType(String value) =>
      RecitationType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => RecitationType.hifz,
      );

  static PointsReason _pointsReason(String value) =>
      PointsReason.values.firstWhere(
        (reason) => reason.name == value,
        orElse: () => PointsReason.other,
      );

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
