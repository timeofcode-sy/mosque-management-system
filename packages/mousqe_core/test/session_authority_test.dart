import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';

import 'support/test_institute.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// ما يملكه الديسكتوب فوق تطبيق الأستاذ — ✅ م.6.4.
///
/// أربعةُ فروق، كلُّها **معاملٌ في نفس المستودع** لا نسخةٌ ثانية منه
/// ([PHASE-6-STAGES.MD §5](../../../docs/PHASE-6-STAGES.MD)):
///
/// 1. الكشفُ معهدٌ كامل لا حلقاتُ صاحب الجهاز.
/// 2. الجلسةُ المكتملة تُحرَّر لحاملِ `attendance.amend` وحده.
/// 3. القفلُ النهائي — نوعُ عمليةٍ فُتح في هذه المرحلة.
/// 4. تفقّدُ الأساتذة — جدولٌ وصف مسوّدةٍ فُتحا في هذه المرحلة.
void main() {
  late AppDatabase db;
  late TestInstitute fixture;
  late SyncEngine engine;
  late CircleRepository repository;

  final day = DateTime(2026, 9, 15);

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fixture = await TestInstitute.seed(db);
    engine = SyncEngine(
      db: db,
      apiClient: _MockApiClient(),
      app: 'admin_desktop',
      deviceUuid: 'desk-1',
    );
    repository = CircleRepository(db: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> queue() async {
    final rows = await (db.select(
      db.pendingOperations,
    )..orderBy([(t) => OrderingTerm.asc(t.sequence)])).get();

    return [
      for (final row in rows)
        {'type': row.type, ...jsonDecode(row.payload) as Map<String, dynamic>},
    ];
  }

  Future<CircleView> circle([String uuid = TestInstitute.circleUuid]) async =>
      (await repository.loadCircles()).firstWhere((c) => c.uuid == uuid);

  group('the roll is the institute, not the device owner', () {
    test('every circle in the running course, each exactly once', () async {
      final circles = await repository.loadCircles();

      // «حلقة الفرقان» بأستاذين — ولو بقي وصلُ الأستاذ مفروضاً لظهرت مرّتين.
      // والترتيبُ بالدوام ثم بالاسم: العصر ثم الفرقان ثم النهار.
      expect(circles.map((c) => c.uuid), [
        TestInstitute.unstaffedCircleUuid,
        TestInstitute.circleUuid,
        TestInstitute.otherCircleUuid,
      ]);
      expect(circles.map((c) => c.uuid).toSet(), hasLength(3));
    });

    test('a circle with no teacher yet is shown, not hidden', () async {
      final unstaffed = await circle(TestInstitute.unstaffedCircleUuid);

      // هي أوّلُ ما يعني المشرف: من يسند إليها أستاذاً هو هو.
      expect(unstaffed.teachers, isEmpty);
      expect(unstaffed.circleName, 'حلقة العصر');
    });

    test('the teacher filter still narrows to their own circles', () async {
      final mine = await repository.loadCircles(TestInstitute.teacherUuid);

      expect(mine.map((c) => c.uuid), [TestInstitute.circleUuid]);
    });

    test('the session log spans the institute when unfiltered', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);
      await fixture.syncSession(
        id: 2,
        uuid: 'ses-2',
        day: day,
        courseCircleId: 2,
      );

      expect(await repository.loadSessionLog(), hasLength(2));
      expect(
        await repository.loadSessionLog(TestInstitute.teacherUuid),
        hasLength(1),
      );
    });
  });

  group('amend: a completed session obeys the permission, not the app', () {
    setUp(() async {
      await fixture.syncSession(
        id: 1,
        uuid: 'ses-1',
        day: day,
        status: 'completed',
      );
    });

    test('the same session is closed to one holder and open to the other',
        () async {
      final session = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );

      // نفسُ الصفّ ونفسُ الشيفرة — والفرقُ ما يملكه فاتحُها.
      expect(session.editableBy(canAmend: false), isFalse);
      expect(session.editableBy(canAmend: true), isTrue);
      expect(session.isAmendment, isTrue);
    });

    test('a locked session is closed to everyone, permission or not', () async {
      await db.delete(db.attendanceSessions).go();
      await fixture.syncSession(
        id: 2,
        uuid: 'ses-2',
        day: day,
        status: 'locked',
      );

      final session = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );

      expect(session.editableBy(canAmend: true), isFalse);
      expect(session.locked, isTrue);
    });

    test('an amendment is declared in the payload the server guards on',
        () async {
      final session = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );

      await repository.saveAttendance(
        session: session,
        entries: [
          session.roster.first.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: DateTime(2026, 9, 15, 9),
          ),
          ...session.roster.skip(1),
        ],
        amend: true,
      );

      final take = (await queue()).single;

      // بلا هذا الحقل يطبّقها الخادمُ بلا حارس — أو يرفضها `TakeAttendance`
      // لأنها على جلسةٍ مكتملة. وهو ما يقرؤه `SyncPush::assertPermitted`.
      expect(take['type'], 'attendance.take');
      expect(take['amend'], isTrue);
    });

    test('an ordinary save carries no amend flag at all', () async {
      await db.delete(db.attendanceSessions).go();
      await fixture.syncSession(id: 3, uuid: 'ses-3', day: day);

      final session = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );

      await repository.saveAttendance(
        session: session,
        entries: [
          session.roster.first.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: day,
          ),
          ...session.roster.skip(1),
        ],
        amend: session.isAmendment,
      );

      expect((await queue()).single.containsKey('amend'), isFalse);
    });
  });

  group('lock: the final door', () {
    test('a draft is completed then locked, in that order', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);

      await repository.lockSession(
        await repository.loadSession(
          circle: await circle(),
          date: day,
          graceMinutes: 0,
        ),
      );

      // `LockAttendanceSession` لا يقبل غيرَ المكتملة، فلو صُفَّ القفلُ وحده
      // لَعاد معزولاً برسالة «لا تُقفل إلا الجلسة المكتملة» بعد ساعات.
      expect((await queue()).map((op) => op['type']), [
        'attendance.session.complete',
        'attendance.session.lock',
      ]);
    });

    test('an already completed session is locked with one operation', () async {
      await fixture.syncSession(
        id: 1,
        uuid: 'ses-1',
        day: day,
        status: 'completed',
      );

      await repository.lockSession(
        await repository.loadSession(
          circle: await circle(),
          date: day,
          graceMinutes: 0,
        ),
      );

      final lock = (await queue()).single;
      expect(lock['type'], 'attendance.session.lock');
      expect(lock['session_uuid'], 'ses-1');
    });

    test('the lock shows on this device before the pull confirms it', () async {
      await fixture.syncSession(
        id: 1,
        uuid: 'ses-1',
        day: day,
        status: 'completed',
      );

      final before = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );
      await repository.lockSession(before);

      final after = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );

      // صفُّ الخادم ما زال `completed` — ولو قُرئ وحده لَوجد القافلُ البابَ
      // مفتوحاً أمامه بعد أن أقفله.
      expect(after.locked, isTrue);
      expect(after.editableBy(canAmend: true), isFalse);
    });

    test('locking a locked session queues nothing', () async {
      await fixture.syncSession(
        id: 1,
        uuid: 'ses-1',
        day: day,
        status: 'locked',
      );

      await repository.lockSession(
        await repository.loadSession(
          circle: await circle(),
          date: day,
          graceMinutes: 0,
        ),
      );

      expect(await queue(), isEmpty);
    });
  });

  group('teacher attendance', () {
    setUp(() async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);
    });

    Future<SessionView> session() async => repository.loadSession(
      circle: await circle(),
      date: day,
      graceMinutes: 0,
      withTeachers: true,
    );

    test('an unrecorded teacher is not presumed present', () async {
      final view = await session();

      expect(view.teacherRoster.map((entry) => entry.fullName), [
        'أحمد بن سعيد',
        'خالد بن عمر',
      ]);
      // الخادمُ يزرع صفوفَ الطلاب «حاضر» عند فتح الجلسة ولا يزرع للأساتذة شيئاً،
      // فادّعاءُ حضورٍ لم يقله أحد كان يجعل غيابَ الأستاذ حضوراً بالسكوت.
      expect(view.teacherRoster.every((entry) => entry.recorded), isFalse);
    });

    test('a synced row is read, and the assistant keeps its label', () async {
      await fixture.syncTeacherAttendance(
        uuid: 'tat-1',
        sessionId: 1,
        teacherId: 2,
        status: 'late',
        lateMinutes: 7,
      );

      final assistant = (await session()).teacherRoster.last;

      expect(assistant.status, AttendanceStatus.late);
      expect(assistant.lateMinutes, 7);
      expect(assistant.recorded, isTrue);
      expect(assistant.pending, isFalse);
      expect(assistant.roleLabel, 'مساعد');
    });

    test('only what changed is queued, and the draft shows at once', () async {
      final view = await session();

      await repository.saveTeacherAttendance(
        session: view,
        entries: [
          view.teacherRoster.first.copyWith(status: AttendanceStatus.absent),
          view.teacherRoster.last,
        ],
      );

      final op = (await queue()).single;
      expect(op['type'], 'attendance.teacher.take');
      expect(op['session_uuid'], 'ses-1');
      expect(op['teacher_attendances'], [
        {'teacher_uuid': TestInstitute.teacherUuid, 'status': 'absent'},
      ]);

      final after = await session();
      expect(after.teacherRoster.first.status, AttendanceStatus.absent);
      expect(after.teacherRoster.first.pending, isTrue);
    });

    test('the teacher roll is not built unless it is asked for', () async {
      final view = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );

      // تطبيقُ الأستاذ لا يتفقّد الأساتذة، فلا يدفع ثمنَ استعلامين لا يعرضهما.
      expect(view.teacherRoster, isEmpty);
    });
  });

  group('the day at a glance', () {
    test('an unopened circle has no entry, and the local draft wins',
        () async {
      await fixture.syncSession(
        id: 1,
        uuid: 'ses-1',
        day: day,
        status: 'completed',
      );

      await repository.lockSession(
        await repository.loadSession(
          circle: await circle(),
          date: day,
          graceMinutes: 0,
        ),
      );

      final statuses = await repository.loadDayStatuses(day);

      expect(statuses[1], 'locked');
      // حلقتان لم تُفتح جلستُهما — وغيابُ المفتاح هو الجواب، لا `draft` مفترَضة.
      expect(statuses.containsKey(2), isFalse);
      expect(statuses.containsKey(3), isFalse);
    });

    test('a stale local draft never drags a locked session backwards',
        () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: day);

      // مسوّدةٌ محلية كتبها هذا الجهاز، ثم أقفلها مشرفٌ آخر ووصل قفلُه في السحب.
      final view = await repository.loadSession(
        circle: await circle(),
        date: day,
        graceMinutes: 0,
      );
      await repository.saveAttendance(
        session: view,
        entries: [
          view.roster.first.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: day,
          ),
          ...view.roster.skip(1),
        ],
      );

      await db.update(db.attendanceSessions).replace(
            (await db.select(db.attendanceSessions).getSingle())
                .copyWith(status: 'locked'),
          );

      expect((await repository.loadDayStatuses(day))[1], 'locked');
    });
  });
}
