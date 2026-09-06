import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_teacher/src/data/teacher_repository.dart';
import 'package:mousqe_teacher/src/data/views.dart';

import 'support/test_institute.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late AppDatabase db;
  late TestInstitute fixture;
  late SyncEngine engine;
  late TeacherRepository repository;

  final day = DateTime(2026, 9, 15);

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fixture = await TestInstitute.seed(db);
    engine = SyncEngine(
      db: db,
      apiClient: _MockApiClient(),
      app: 'teacher',
      deviceUuid: 'device-1',
    );
    repository = TeacherRepository(db: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  Future<CircleView> myCircle() async =>
      (await repository.loadCircles(TestInstitute.teacherUuid)).single;

  Future<List<Map<String, dynamic>>> queue() async {
    final rows = await (db.select(
      db.pendingOperations,
    )..orderBy([(t) => OrderingTerm.asc(t.sequence)])).get();

    return [
      for (final row in rows)
        {'type': row.type, ...jsonDecode(row.payload) as Map<String, dynamic>},
    ];
  }

  group('loadCircles', () {
    test('returns only the circles assigned to this teacher', () async {
      final circles = await repository.loadCircles(TestInstitute.teacherUuid);

      // «حلقة النهار» في نفس المعهد ووصلت الجهاز في السحب — والسحب معهدٌ كامل.
      // ظهورُها هنا يعني أن الترشيح ضاع (SYNC-PROTOCOL §8 البند 7).
      expect(circles.map((circle) => circle.uuid), [TestInstitute.circleUuid]);
      expect(circles.single.circleName, 'حلقة الفرقان');
      expect(circles.single.shiftStartsAt, TestInstitute.shiftStartsAt);
      expect(circles.single.studentsCount, 3);
    });

    test(
      'a teacher with no assignment sees nothing rather than everything',
      () async {
        expect(await repository.loadCircles('tch-nobody'), isEmpty);
      },
    );
  });

  group('loadSession', () {
    test('an unopened day is a roster of suggestions not a record', () async {
      final session = await repository.loadSession(
        circle: await myCircle(),
        date: day,
        graceMinutes: 0,
      );

      expect(session.exists, isFalse);
      expect(session.editable, isTrue);
      expect(session.roster, hasLength(3));
      expect(
        session.roster.every(
          (entry) => entry.origin == AttendanceOrigin.suggested,
        ),
        isTrue,
      );
      // نظير الزرع الخادمي: «حاضر» افتراضاً.
      expect(session.countOf(AttendanceStatus.present), 3);
    });

    test(
      'an approved excuse covering the day suggests excused not present',
      () async {
        await fixture.approveExcuse(TestInstitute.badr, day);

        final session = await repository.loadSession(
          circle: await myCircle(),
          date: day,
          graceMinutes: 0,
        );

        final badr = session.roster.firstWhere(
          (entry) => entry.studentId == TestInstitute.badr,
        );
        expect(badr.status, AttendanceStatus.excused);
        expect(session.countOf(AttendanceStatus.present), 2);
      },
    );

    test('a backdated day shows the circle as it was, not as it is', () async {
      // جميل انضمّ في 09-10، فتفقُّدُ 09-05 لا يراه.
      final session = await repository.loadSession(
        circle: await myCircle(),
        date: DateTime(2026, 9, 5),
        graceMinutes: 0,
      );

      expect(
        session.roster.map((entry) => entry.studentId),
        isNot(contains(TestInstitute.jamil)),
      );
      expect(session.roster, hasLength(2));
    });

    test('a completed session is not editable', () async {
      await fixture.syncSession(
        id: 1,
        uuid: 'ses-1',
        day: day,
        status: 'completed',
      );

      final session = await repository.loadSession(
        circle: await myCircle(),
        date: day,
        graceMinutes: 0,
      );

      // الأستاذ لا يملك attendance.amend، فالمنعُ هنا يوفّر عليه طابوراً مرفوضاً.
      expect(session.editable, isFalse);
    });

    test('a local draft is shown above the synced row it replaces', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);
      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'present',
      );

      final circle = await myCircle();
      var session = await repository.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );
      final ali = session.roster.firstWhere(
        (entry) => entry.studentId == TestInstitute.ali,
      );
      expect(ali.origin, AttendanceOrigin.synced);

      await repository.saveAttendance(
        session: session,
        entries: [
          ali.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: DateTime(2026, 9, 15, 8, 30),
          ),
        ],
      );

      session = await repository.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );
      final updated = session.roster.firstWhere(
        (entry) => entry.studentId == TestInstitute.ali,
      );

      expect(updated.status, AttendanceStatus.absent);
      expect(updated.origin, AttendanceOrigin.pending);
    });
  });

  group('saveAttendance offline', () {
    test(
      'opens the session and takes attendance in that order, in one queue',
      () async {
        final circle = await myCircle();
        final session = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 0,
        );

        await repository.saveAttendance(
          session: session,
          entries: [
            for (final entry in session.roster)
              entry.copyWith(
                origin: AttendanceOrigin.pending,
                recordedAt: DateTime(2026, 9, 15, 8, 20),
              ),
          ],
        );

        final operations = await queue();

        expect(operations.map((op) => op['type']), [
          'attendance.session.open',
          'attendance.take',
        ]);

        // المعرّف الذي ولّده الجهاز هو نفسه في العمليتين — بلا ذلك تفشل الثانية
        // بـ404 على خادمٍ لا يعرف الجلسة بعد.
        expect(operations[1]['session_uuid'], operations[0]['uuid']);

        // والمفتاح الطبيعي مرفقٌ في الاثنتين لأن المعرّف قد لا يطابق شيئاً على
        // الخادم إن سبقنا أحدٌ إلى فتح جلسة اليوم.
        for (final operation in operations) {
          expect(operation['course_circle_uuid'], TestInstitute.circleUuid);
          expect(operation['session_date'], '2026-09-15');
        }

        expect((operations[1]['attendances'] as List), hasLength(3));
      },
    );

    test('an already open session queues the take alone', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);

      final circle = await myCircle();
      final session = await repository.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );

      await repository.saveAttendance(
        session: session,
        entries: [
          session.roster.first.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: DateTime(2026, 9, 15, 8, 20),
          ),
        ],
      );

      final operations = await queue();
      expect(operations.map((op) => op['type']), ['attendance.take']);
      expect(operations.single['session_uuid'], 'ses-1');
    });

    test(
      'only touched rows are sent, and each carries the device clock',
      () async {
        final circle = await myCircle();
        final session = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 0,
        );
        final ali = session.roster.firstWhere(
          (entry) => entry.studentId == TestInstitute.ali,
        );

        await repository.saveAttendance(
          session: session,
          entries: [
            ...session.roster.where(
              (entry) => entry.studentId != TestInstitute.ali,
            ),
            ali.copyWith(
              status: AttendanceStatus.absent,
              origin: AttendanceOrigin.pending,
              recordedAt: DateTime.utc(2026, 9, 15, 5, 20),
            ),
          ],
        );

        final take = (await queue()).last;
        final rows = (take['attendances'] as List).cast<Map<String, dynamic>>();

        expect(rows, hasLength(1));
        expect(rows.single['student_uuid'], 'stu-ali');
        // زمنُ الحدث لا زمنُ الإرسال — مفتاح حسم التعارض (SYNC-PROTOCOL §8 البند 2).
        expect(rows.single['recorded_at'], '2026-09-15T05:20:00.000Z');
      },
    );

    test(
      'late minutes are left for the server unless the teacher typed them',
      () async {
        final circle = await myCircle();
        final session = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 0,
        );
        final roster = session.roster;

        await repository.saveAttendance(
          session: session,
          entries: [
            roster[0].copyWith(
              status: AttendanceStatus.late,
              origin: AttendanceOrigin.pending,
              recordedAt: DateTime(2026, 9, 15, 8, 25),
              lateMinutes: 25,
            ),
            roster[1].copyWith(
              status: AttendanceStatus.late,
              origin: AttendanceOrigin.pending,
              recordedAt: DateTime(2026, 9, 15, 8, 25),
              lateMinutes: 40,
              lateMinutesOverride: 40,
            ),
          ],
        );

        final rows = ((await queue()).last['attendances'] as List)
            .cast<Map<String, dynamic>>();
        final computed = rows.firstWhere(
          (row) => row['student_uuid'] == roster[0].studentUuid,
        );
        final manual = rows.firstWhere(
          (row) => row['student_uuid'] == roster[1].studentUuid,
        );

        // الرقم المعروض محسوبٌ محلياً للعرض فقط، فلا يُرسَل: تركُه فارغاً هو ما
        // يجعل الخادم يحسبه من بداية الدوام (API.md §6).
        expect(computed.containsKey('late_minutes'), isFalse);
        expect(manual['late_minutes'], 40);
      },
    );

    test(
      'the computed number is shown offline the moment late is tapped',
      () async {
        final circle = await myCircle();
        final session = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 5,
        );

        await repository.saveAttendance(
          session: session,
          entries: [
            session.roster.first.copyWith(
              status: AttendanceStatus.late,
              origin: AttendanceOrigin.pending,
              // الدوام يبدأ 08:00 والوصول 08:23 وفترة السماح 5 ⇒ 18.
              recordedAt: DateTime(2026, 9, 15, 8, 23),
            ),
          ],
        );

        final reloaded = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 5,
        );
        final entry = reloaded.roster.firstWhere(
          (row) => row.status == AttendanceStatus.late,
        );

        expect(entry.lateMinutes, 18);
        expect(entry.lateMinutesOverride, isNull);
      },
    );
  });

  group('completeSession', () {
    test('queues the close and locks the day locally', () async {
      final circle = await myCircle();
      var session = await repository.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );

      await repository.saveAttendance(
        session: session,
        entries: [
          session.roster.first.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: DateTime(2026, 9, 15, 8, 20),
          ),
        ],
      );

      session = await repository.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );
      await repository.completeSession(session);

      expect((await queue()).map((op) => op['type']), [
        'attendance.session.open',
        'attendance.take',
        'attendance.session.complete',
      ]);

      final closed = await repository.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );
      expect(closed.status, 'completed');
      expect(closed.editable, isFalse);
    });
  });

  group('clearSettledDrafts', () {
    test('keeps the draft while anything is still queued', () async {
      final circle = await myCircle();
      final session = await repository.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );

      await repository.saveAttendance(
        session: session,
        entries: [
          session.roster.first.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: DateTime(2026, 9, 15, 8, 20),
          ),
        ],
      );

      await repository.clearSettledDrafts();

      expect(await db.select(db.localAttendances).get(), isNotEmpty);
      expect(await db.select(db.localSessions).get(), isNotEmpty);
    });

    test(
      'drops it once the queue is empty and the server rows have landed',
      () async {
        final circle = await myCircle();
        final session = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 0,
        );

        await repository.saveAttendance(
          session: session,
          entries: [
            session.roster.first.copyWith(
              status: AttendanceStatus.absent,
              origin: AttendanceOrigin.pending,
              recordedAt: DateTime(2026, 9, 15, 8, 20),
            ),
          ],
        );

        // ما يفعله المحرّك بعد دفعةٍ التزم بها الخادم وسحبٍ أعادها مطبَّقة.
        await db.delete(db.pendingOperations).go();
        await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);
        await fixture.syncAttendance(
          uuid: 'att-1',
          sessionId: 1,
          studentId: TestInstitute.ali,
          status: 'absent',
        );

        await repository.clearSettledDrafts();

        expect(await db.select(db.localAttendances).get(), isEmpty);

        final settled = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 0,
        );
        final ali = settled.roster.firstWhere(
          (entry) => entry.studentId == TestInstitute.ali,
        );

        expect(ali.status, AttendanceStatus.absent);
        expect(ali.origin, AttendanceOrigin.synced);
        expect(settled.serverUuid, 'ses-1');
      },
    );
  });

  group('loadSessionLog', () {
    test('shows this teachers sessions and not the institutes', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-mine', day: day);
      await fixture.syncSession(
        id: 2,
        uuid: 'ses-other',
        day: day,
        courseCircleId: 2,
      );

      final log = await repository.loadSessionLog(TestInstitute.teacherUuid);

      expect(log.map((entry) => entry.uuid), ['ses-mine']);
    });
  });

  group('recitation and points', () {
    test(
      'a recitation is queued with the range and no computed lines',
      () async {
        final circle = await myCircle();
        await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);
        final session = await repository.loadSession(
          circle: circle,
          date: day,
          graceMinutes: 0,
        );

        await repository.saveRecitation(
          session: session,
          studentUuid: 'stu-ali',
          type: RecitationType.hifz,
          fromSurah: 78,
          fromAyah: 1,
          toSurah: 78,
          toAyah: 40,
          grade: RecitationGrade.veryGood,
        );

        final operation = (await queue()).single;
        final recitation = operation['recitation'] as Map<String, dynamic>;

        expect(operation['type'], 'recitation.save');
        expect(operation['session_uuid'], 'ses-1');
        expect(recitation['from_surah'], 78);
        // `veryGood` ⇒ `very_good`: الخادم يقرأ snake_case لا camelCase.
        expect(recitation['grade'], 'very_good');
        // الأسطر والنقاط يحسبها الخادم ويجمّدها — إرسالُها من هنا يخلق حقيقةً ثانية.
        expect(recitation.containsKey('lines'), isFalse);
        expect(recitation.containsKey('points'), isFalse);
      },
    );

    test('points are queued with reason and date', () async {
      await repository.awardPoints(
        studentUuid: 'stu-badr',
        points: 2.5,
        reason: PointsReason.participation,
        note: 'إجابة ممتازة',
      );

      final operation = (await queue()).single;

      expect(operation['type'], 'points.award');
      expect(operation['points'], 2.5);
      expect(operation['reason'], 'participation');
      expect(operation['note'], 'إجابة ممتازة');
    });
  });
}
