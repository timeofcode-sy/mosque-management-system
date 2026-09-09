import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:retrofit/retrofit.dart';

import 'support/test_institute.dart';

/// خادمٌ مصغَّر يطبّق ما يطبّقه `SyncPush` ويبثّ ما يبثّه `change_log`.
///
/// ليس محاكاةً للـ HTTP بل لِعقد المزامنة: `op_uuid` يمنع التكرار، والفتحُ يزرع
/// صفوفَ حضورٍ افتراضية، والجلسةُ تُحسَم بمفتاحها الطبيعي حين لا يطابق المعرّف
/// شيئاً — وهي الحالات الثلاث التي يقوم عليها عملُ التطبيق بلا شبكة.
///
/// 🔄 **م.6.4: ويحسم التعارض أيضاً** — نظير `ResolveAttendanceConflicts` بشروطه
/// الأربعة، ويقفل الجلسة بشرط `LockAttendanceSession`. أُضيفا لأن **العميلَ
/// الثاني صار موجوداً**، فصارت الخطوة 3 من السيناريو المرجعي قابلةً للتشغيل
/// ([SYNC-PROTOCOL.md §9](../../../../docs/SYNC-PROTOCOL.md)).
class _FakeServer implements ApiClient {
  _FakeServer({required this.circleUuid, required this.studentUuids});

  final String circleUuid;

  /// معرّفات طلاب الحلقة، مفهرسةً بمعرّفها المحلي في drift.
  final Map<int, String> studentUuids;

  final List<Map<String, dynamic>> changes = [];
  final Set<String> _appliedOps = {};

  /// جلسات الخادم بمفتاحها الطبيعي: `courseCircleUuid|date`.
  final Map<String, Map<String, dynamic>> _sessions = {};

  /// صفوف الحضور: `sessionKey|studentUuid`.
  final Map<String, Map<String, dynamic>> _attendances = {};

  bool offline = false;
  int _seq = 0;
  int _nextId = 100;

  /// ما رفضه الخادمُ من صفوف بحكم «الأحدث يفوز» — نظير جدول `sync_conflicts`،
  /// وهو ما تعرضه شاشةُ التعارضات في م.6.6.
  final List<Map<String, dynamic>> conflicts = [];

  int get pushCount => _pushCount;
  int _pushCount = 0;

  @override
  Future<HttpResponse<dynamic>> syncPush(Map<String, dynamic> body) async {
    _pushCount += 1;

    if (offline) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
    }

    final applied = <String>[];
    final skipped = <String>[];
    final failed = <Map<String, dynamic>>[];

    for (final raw in body['operations'] as List) {
      final op = (raw as Map).cast<String, dynamic>();
      final opUuid = op['op_uuid'] as String;

      if (!_appliedOps.add(opUuid)) {
        skipped.add(opUuid);
        continue;
      }

      // كلُّ عملية في معاملتها، والمرفوضةُ في failed[] ويمضي الباقي — م.6.1.
      try {
        switch (op['type']) {
          case 'attendance.session.open':
            _open(op);
          case 'attendance.take':
            _take(op, body['device_uuid'] as String?);
          case 'attendance.session.complete':
            _complete(op);
          case 'attendance.session.lock':
            _lock(op);
        }
      } on StateError catch (error) {
        _appliedOps.remove(opUuid);
        failed.add({'op_uuid': opUuid, 'message': error.message});
        continue;
      }

      applied.add(opUuid);
    }

    return _ok({'applied': applied, 'skipped': skipped, 'failed': failed});
  }

  @override
  Future<HttpResponse<dynamic>> syncPull(
    int since,
    String app,
    String? deviceUuid,
  ) async {
    if (offline) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
    }

    final page = changes
        .where((change) => (change['server_seq'] as int) > since)
        .toList();

    return _ok({
      'server_seq': page.isEmpty ? since : page.last['server_seq'],
      'changes': page,
    });
  }

  String _key(Map<String, dynamic> op) =>
      '${op['course_circle_uuid']}|${op['session_date']}';

  void _open(Map<String, dynamic> op) {
    final key = _key(op);

    if (_sessions.containsKey(key)) {
      return; // firstOrCreate: القائمةُ تحتفظ بمعرّفها.
    }

    final session = {
      'id': _nextId++,
      // المعرّف الذي ولّده العميل يُستعمل عند الإنشاء وحده.
      'uuid': op['uuid'] as String? ?? 'server-${_nextId++}',
      'course_circle_id': 1,
      'session_date': op['session_date'],
      'status': 'draft',
      'completed_at': null,
    };

    _sessions[key] = session;
    _record('attendance_sessions', 'create', session);

    // الزرع: صفٌّ لكل طالب بحالة «حاضر»، بلا device_uuid — قيمةٌ لم يقلها أحد.
    for (final studentId in studentUuids.keys) {
      _writeAttendance(
        key,
        studentId,
        'present',
        null,
        '2026-09-15T05:00:00.000Z',
        'create',
      );
    }
  }

  void _take(Map<String, dynamic> op, String? deviceUuid) {
    final key = _sessionKeyFor(op);
    final session = _sessions[key]!;

    // نظير حارس TakeAttendance: المقفلةُ لا تُعدَّل، والمكتملةُ لا تُعدَّل إلا
    // بـ amend صريح — وهو ما يحرسه SyncPush::assertPermitted بـ attendance.amend.
    if (session['status'] == 'locked') {
      throw StateError('الجلسة مقفلة ولا تقبل التعديل.');
    }

    if (session['status'] == 'completed' && op['amend'] != true) {
      throw StateError('الجلسة مغلقة — التعديل يحتاج amend.');
    }

    for (final raw in op['attendances'] as List) {
      final row = (raw as Map).cast<String, dynamic>();
      final studentId = studentUuids.entries
          .firstWhere((entry) => entry.value == row['student_uuid'])
          .key;

      if (_losesConflict(key, studentId, row, deviceUuid)) {
        continue;
      }

      _writeAttendance(
        key,
        studentId,
        row['status'] as String,
        // نظير TakeAttendance: المرسَل يغلب، وإلا حُسب من بداية الدوام.
        row['status'] == 'late' ? (row['late_minutes'] as int? ?? 23) : null,
        row['recorded_at'] as String,
        'update',
        deviceUuid,
      );
    }
  }

  /// شروطُ `ResolveAttendanceConflicts` الأربعة مجتمعةً: صفٌّ قائم، كتبه **جهازٌ
  /// آخر** كتابةً حقيقية (لا زرعَ الفتح)، و`recorded_at` القائم **أحدث**، والحالةُ
  /// **مختلفة**. وما دونها ليس نزاعاً بل تحديثاً عادياً.
  bool _losesConflict(
    String sessionKey,
    int studentId,
    Map<String, dynamic> incoming,
    String? deviceUuid,
  ) {
    final current = _attendances['$sessionKey|$studentId'];

    if (current == null) {
      return false;
    }

    final writtenByAnother = changes.any(
      (change) =>
          change['table_name'] == 'attendances' &&
          change['row_uuid'] == current['uuid'] &&
          change['device_uuid'] != null &&
          change['device_uuid'] != deviceUuid,
    );

    final currentAt = DateTime.parse(current['recorded_at'] as String);
    final incomingAt = DateTime.parse(incoming['recorded_at'] as String);

    if (!writtenByAnother ||
        !currentAt.isAfter(incomingAt) ||
        current['status'] == incoming['status']) {
      return false;
    }

    conflicts.add({
      'row_uuid': current['uuid'],
      'server_payload': Map<String, dynamic>.from(current),
      'client_payload': incoming,
      'device_uuid': deviceUuid,
    });

    return true;
  }

  /// نظير `LockAttendanceSession`: لا تُقفل إلا المكتملة.
  void _lock(Map<String, dynamic> op) {
    final session = _sessions[_sessionKeyFor(op)]!;

    if (session['status'] != 'completed') {
      throw StateError('لا تُقفل إلا الجلسة المكتملة.');
    }

    session['status'] = 'locked';
    _record('attendance_sessions', 'update', session);
  }

  void _complete(Map<String, dynamic> op) {
    final session = _sessions[_sessionKeyFor(op)]!;
    session['status'] = 'completed';
    session['completed_at'] = '2026-09-15T06:00:00.000Z';
    _record('attendance_sessions', 'update', session);
  }

  /// نظير `SyncPush::attendanceSession`: بالمعرّف، وإلا بالمفتاح الطبيعي.
  String _sessionKeyFor(Map<String, dynamic> op) {
    final byUuid = _sessions.entries
        .where((entry) => entry.value['uuid'] == op['session_uuid'])
        .firstOrNull;

    if (byUuid != null) {
      return byUuid.key;
    }

    final natural = _key(op);

    if (_sessions.containsKey(natural)) {
      return natural;
    }

    throw StateError('لا جلسة تطابق ${op['session_uuid']} ولا $natural');
  }

  void _writeAttendance(
    String sessionKey,
    int studentId,
    String status,
    int? lateMinutes,
    String recordedAt,
    String operation, [
    String? deviceUuid,
  ]) {
    final rowKey = '$sessionKey|$studentId';
    final existing = _attendances[rowKey];

    final row = {
      'id': existing?['id'] ?? _nextId++,
      'uuid': existing?['uuid'] ?? 'att-$rowKey',
      'attendance_session_id': _sessions[sessionKey]!['id'],
      'student_id': studentId,
      'status': status,
      'late_minutes': lateMinutes,
      'note': null,
      'note_polarity': null,
      'recorded_at': recordedAt,
    };

    _attendances[rowKey] = row;
    _record(
      'attendances',
      existing == null ? 'create' : operation,
      row,
      deviceUuid,
    );
  }

  /// و`device_uuid` يُسجَّل مع الصفّ لا مع الطلب: به وحده يميّز حاسمُ التعارض
  /// **كتابةً حقيقية من جهازٍ آخر** من زرع الفتح الذي لم يقله أحد.
  void _record(
    String table,
    String operation,
    Map<String, dynamic> payload, [
    String? deviceUuid,
  ]) {
    changes.add({
      'server_seq': ++_seq,
      'table_name': table,
      'operation': operation,
      'row_uuid': payload['uuid'],
      'device_uuid': deviceUuid,
      'payload': Map<String, dynamic>.from(payload),
    });
  }

  HttpResponse<dynamic> _ok(Map<String, dynamic> data) => HttpResponse(
    data,
    Response(requestOptions: RequestOptions(), data: data),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late _FakeServer server;
  late SyncEngine engine;
  late CircleRepository repository;

  final day = DateTime(2026, 9, 15);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await TestInstitute.seed(db);
    server = _FakeServer(
      circleUuid: TestInstitute.circleUuid,
      studentUuids: const {
        TestInstitute.ali: 'stu-ali',
        TestInstitute.badr: 'stu-badr',
        TestInstitute.jamil: 'stu-jamil',
      },
    );
    engine = SyncEngine(
      db: db,
      apiClient: server,
      app: 'teacher',
      deviceUuid: 'device-1',
    );
    repository = CircleRepository(db: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  Future<CircleView> myCircle() async =>
      (await repository.loadCircles(TestInstitute.teacherUuid)).single;

  Future<SessionView> read(CircleView circle) =>
      repository.loadSession(circle: circle, date: day, graceMinutes: 0);

  /// الخطوات 2→4 من السيناريو المرجعي ([SYNC-PROTOCOL.md §9](../../../../docs/SYNC-PROTOCOL.md)):
  /// يومٌ كامل بلا شبكة، ثم عودةُ الاتصال.
  test('a full offline day survives the network coming back', () async {
    final circle = await myCircle();

    server.offline = true;

    var session = await read(circle);
    await repository.saveAttendance(
      session: session,
      entries: [
        for (final entry in session.roster)
          switch (entry.studentId) {
            TestInstitute.badr => entry.copyWith(
              status: AttendanceStatus.absent,
              origin: AttendanceOrigin.pending,
              recordedAt: DateTime.utc(2026, 9, 15, 5, 20),
            ),
            TestInstitute.jamil => entry.copyWith(
              status: AttendanceStatus.late,
              origin: AttendanceOrigin.pending,
              recordedAt: DateTime.utc(2026, 9, 15, 5, 23),
            ),
            _ => entry.copyWith(
              origin: AttendanceOrigin.pending,
              recordedAt: DateTime.utc(2026, 9, 15, 5, 20),
            ),
          },
      ],
    );

    session = await read(circle);
    await repository.completeSession(session);

    // محاولةُ مزامنةٍ بلا شبكة: لا شيء يُفقَد، والطابور كما هو.
    await engine.sync().catchError((_) {});
    await repository.clearSettledDrafts();

    expect(await db.select(db.pendingOperations).get(), hasLength(3));

    final offlineView = await read(circle);
    expect(offlineView.status, 'completed');
    expect(offlineView.editableBy(canAmend: false), isFalse);
    expect(offlineView.countOf(AttendanceStatus.absent), 1);
    expect(offlineView.hasPendingRows, isTrue);

    // ── عودة الاتصال ──────────────────────────────────────────────────────
    server.offline = false;
    await engine.sync();
    await repository.clearSettledDrafts();

    expect(await db.select(db.pendingOperations).get(), isEmpty);
    expect(await db.select(db.localAttendances).get(), isEmpty);

    final settled = await read(circle);

    expect(settled.serverUuid, isNotNull);
    expect(settled.status, 'completed');
    expect(
      settled.roster.every((entry) => entry.origin == AttendanceOrigin.synced),
      isTrue,
    );
    expect(settled.countOf(AttendanceStatus.present), 1);
    expect(settled.countOf(AttendanceStatus.absent), 1);
    expect(settled.countOf(AttendanceStatus.late), 1);

    // الرقم يحسبه الخادم لأن العميل تركه فارغاً عمداً.
    final late = settled.roster.firstWhere(
      (entry) => entry.status == AttendanceStatus.late,
    );
    expect(late.lateMinutes, 23);
  });

  test('a resent batch is skipped not applied twice', () async {
    final circle = await myCircle();
    final session = await read(circle);

    await repository.saveAttendance(
      session: session,
      entries: [
        session.roster.first.copyWith(
          status: AttendanceStatus.absent,
          origin: AttendanceOrigin.pending,
          recordedAt: DateTime.utc(2026, 9, 15, 5, 20),
        ),
      ],
    );

    await engine.sync();
    final afterFirst = server.changes.length;

    // إعادةُ الإرسال بعد انقطاعٍ في طريق الاستجابة: الطابور فرغ، فلا شيء يُرسَل
    // ثانيةً — وحتى لو أُرسل، `op_uuid` يجعله بلا أثر (SYNC-PROTOCOL §3).
    await engine.sync();

    expect(server.changes.length, afterFirst);
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });

  test(
    'the session another device opened first wins, and our take still lands',
    () async {
      final circle = await myCircle();

      // جهازُ المشرف فتح جلسةَ اليوم بمعرّفٍ خاصّ به قبل أن نتصل نحن.
      await server.syncPush({
        'operations': [
          {
            'op_uuid': 'op-supervisor',
            'type': 'attendance.session.open',
            'uuid': 'ses-supervisor',
            'course_circle_uuid': TestInstitute.circleUuid,
            'session_date': '2026-09-15',
          },
        ],
      });

      server.offline = true;
      final session = await read(circle);
      await repository.saveAttendance(
        session: session,
        entries: [
          session.roster.first.copyWith(
            status: AttendanceStatus.absent,
            origin: AttendanceOrigin.pending,
            recordedAt: DateTime.utc(2026, 9, 15, 5, 20),
          ),
        ],
      );

      server.offline = false;
      await engine.sync();
      await repository.clearSettledDrafts();

      final settled = await read(circle);

      // معرّفُنا المحلي سقط، وتفقُّدُنا وصل — بالمفتاح الطبيعي المرفق بالعملية.
      expect(settled.serverUuid, 'ses-supervisor');
      expect(settled.countOf(AttendanceStatus.absent), 1);
      expect(await db.select(db.attendanceSessions).get(), hasLength(1));
    },
  );

  /// ── الخطوة 3 من السيناريو المرجعي — ✅ م.6.4 ──────────────────────────────
  ///
  /// «من الديسكتوب: عدّل حالة أحد الطلاب في نفس الجلسة وهو أوف-لاين أيضاً»
  /// ([SYNC-PROTOCOL.md §9](../../../../docs/SYNC-PROTOCOL.md)). بقيت غيرَ مُشغَّلة
  /// منذ م.5.3 لسببٍ واحد: **لا عميلَ ثانٍ**. وقد صار موجوداً، فهذه المجموعة
  /// جهازان بمخزنين ومؤشّرَي مزامنة على خادمٍ واحد.
  group('two devices editing in parallel', () {
    late AppDatabase deskDb;
    late SyncEngine deskEngine;
    late CircleRepository desk;

    setUp(() async {
      deskDb = AppDatabase(NativeDatabase.memory());
      await TestInstitute.seed(deskDb);
      deskEngine = SyncEngine(
        db: deskDb,
        apiClient: server,
        app: 'admin_desktop',
        deviceUuid: 'device-2',
      );
      desk = CircleRepository(db: deskDb, syncEngine: deskEngine);
    });

    tearDown(() => deskDb.close());

    Future<CircleView> deskCircle() async =>
        (await desk.loadCircles()).firstWhere(
          (circle) => circle.uuid == TestInstitute.circleUuid,
        );

    Future<void> mark(
      CircleRepository repo,
      CircleView circle,
      int studentId,
      AttendanceStatus status,
      DateTime at, {
      bool amend = false,
    }) async {
      final session = await repo.loadSession(
        circle: circle,
        date: day,
        graceMinutes: 0,
      );

      await repo.saveAttendance(
        session: session,
        entries: [
          for (final entry in session.roster)
            if (entry.studentId == studentId)
              entry.copyWith(
                status: status,
                origin: AttendanceOrigin.pending,
                recordedAt: at,
              )
            else
              entry,
        ],
        amend: amend,
      );
    }

    /// يومٌ أغلقه الأستاذ فعلاً: **الجلسةُ لا توجد حتى يُحفظ فيها تفقّد** —
    /// `completeSession` وحده لا يفتحها، وهو نفسُ ترتيب `attendance.session.open`
    /// قبل `attendance.take` في الطابور.
    Future<void> teacherClosesTheDay() async {
      await mark(
        repository,
        await myCircle(),
        TestInstitute.badr,
        AttendanceStatus.absent,
        DateTime.utc(2026, 9, 15, 5, 20),
      );
      await repository.completeSession(
        await repository.loadSession(
          circle: await myCircle(),
          date: day,
          graceMinutes: 0,
        ),
      );
      await engine.sync();
      await repository.clearSettledDrafts();
    }

    test('the later write wins and the earlier one is logged, not lost',
        () async {
      server.offline = true;

      // الأستاذ في المسجد يسجّل «غائب» الساعة 5:20، والمشرفُ في مكتبه يسجّل
      // «مأذون» لنفس الطالب الساعة 5:40 — كلاهما بلا شبكة ولا يعرف الآخر.
      await mark(
        repository,
        await myCircle(),
        TestInstitute.badr,
        AttendanceStatus.absent,
        DateTime.utc(2026, 9, 15, 5, 20),
      );
      await mark(
        desk,
        await deskCircle(),
        TestInstitute.badr,
        AttendanceStatus.excused,
        DateTime.utc(2026, 9, 15, 5, 40),
      );

      // ── عودةُ الشبكة: المشرفُ أوّلاً (الأحدثُ يصل أوّلاً) ثم الأستاذ ──
      server.offline = false;
      await deskEngine.sync();
      await engine.sync();

      // «الأحدثُ يفوز» — والأقدمُ لا يُكتب فوقه ولا يضيع: يُسجَّل في التعارضات
      // ليراجعه المشرف بعدياً (شاشةُ م.6.6).
      expect(server.conflicts, hasLength(1));
      expect(server.conflicts.single['client_payload']['status'], 'absent');
      expect(server.conflicts.single['device_uuid'], 'device-1');

      await deskEngine.sync();
      await desk.clearSettledDrafts();

      final settled = await desk.loadSession(
        circle: await deskCircle(),
        date: day,
        graceMinutes: 0,
      );
      final badr = settled.roster.firstWhere(
        (entry) => entry.studentId == TestInstitute.badr,
      );

      expect(badr.status, AttendanceStatus.excused);
      expect(badr.origin, AttendanceOrigin.synced);
    });

    test('two devices marking two different students never contend', () async {
      server.offline = true;

      await mark(
        repository,
        await myCircle(),
        TestInstitute.badr,
        AttendanceStatus.absent,
        DateTime.utc(2026, 9, 15, 5, 20),
      );
      await mark(
        desk,
        await deskCircle(),
        TestInstitute.jamil,
        AttendanceStatus.late,
        DateTime.utc(2026, 9, 15, 5, 10),
      );

      server.offline = false;
      await deskEngine.sync();
      await engine.sync();
      await deskEngine.sync();
      await desk.clearSettledDrafts();

      // التعارضُ نزاعٌ على **طالبٍ بعينه** لا على الجلسة كلّها — وهو ما صحّحه
      // انتقالُ الفحص من مستوى الجلسة إلى مستوى الصفّ.
      expect(server.conflicts, isEmpty);

      final settled = await desk.loadSession(
        circle: await deskCircle(),
        date: day,
        graceMinutes: 0,
      );

      expect(settled.countOf(AttendanceStatus.absent), 1);
      expect(settled.countOf(AttendanceStatus.late), 1);
    });

    test('the supervisor amends what the teacher closed, and the teacher sees it',
        () async {
      // الأستاذ يتفقّد ويُكمل ويزامن.
      await teacherClosesTheDay();

      await deskEngine.sync();
      final closed = await desk.loadSession(
        circle: await deskCircle(),
        date: day,
        graceMinutes: 0,
      );
      expect(closed.editableBy(canAmend: false), isFalse);
      expect(closed.editableBy(canAmend: true), isTrue);

      // المشرفُ يصحّح بعد الإقفال — وهي الصلاحيةُ التي تميّز الديسكتوب.
      await mark(
        desk,
        await deskCircle(),
        TestInstitute.badr,
        AttendanceStatus.excused,
        DateTime.utc(2026, 9, 15, 9),
        amend: true,
      );
      await deskEngine.sync();

      // ولا معزولةَ في طابور المشرف: الخادمُ قبل التصحيح لأنه أُعلن.
      expect(await deskEngine.watchFailedOperations().first, isEmpty);

      await engine.sync();
      final onTeacherDevice = await repository.loadSession(
        circle: await myCircle(),
        date: day,
        graceMinutes: 0,
      );

      // التصحيحُ يصل جهازَ الأستاذ في السحب — يراه ولا يعدّله.
      expect(
        onTeacherDevice.roster
            .firstWhere((entry) => entry.studentId == TestInstitute.badr)
            .status,
        AttendanceStatus.excused,
      );
      expect(onTeacherDevice.editableBy(canAmend: false), isFalse);
    });

    test('an unannounced edit on a closed session is quarantined, not applied',
        () async {
      await teacherClosesTheDay();
      await deskEngine.sync();

      // نفسُ الكتابة بلا `amend`: الخادمُ يردّها في failed[] فتُعزل في الجهاز،
      // ولا تحجب ما بعدها ولا تُعاد آلياً (م.6.1 + م.6.2).
      await mark(
        desk,
        await deskCircle(),
        TestInstitute.badr,
        AttendanceStatus.excused,
        DateTime.utc(2026, 9, 15, 9),
      );
      await deskEngine.sync();

      final quarantined = await deskEngine.watchFailedOperations().first;
      expect(quarantined, hasLength(1));
      expect(quarantined.single.type, 'attendance.take');
      expect(server.conflicts, isEmpty);
    });

    test('a locked session is closed to the teacher and to the supervisor',
        () async {
      await teacherClosesTheDay();
      await deskEngine.sync();

      await desk.lockSession(
        await desk.loadSession(
          circle: await deskCircle(),
          date: day,
          graceMinutes: 0,
        ),
      );
      await deskEngine.sync();
      await desk.clearSettledDrafts();

      await engine.sync();

      final onTeacherDevice = await repository.loadSession(
        circle: await myCircle(),
        date: day,
        graceMinutes: 0,
      );
      final onDesk = await desk.loadSession(
        circle: await deskCircle(),
        date: day,
        graceMinutes: 0,
      );

      // القفلُ نهائيّ: لا صلاحيةَ تنقضه على أيّ من الجهازين.
      expect(onTeacherDevice.locked, isTrue);
      expect(onTeacherDevice.editableBy(canAmend: false), isFalse);
      expect(onDesk.editableBy(canAmend: true), isFalse);
    });
  });
}
