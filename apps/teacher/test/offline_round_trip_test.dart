import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_teacher/src/data/teacher_repository.dart';
import 'package:mousqe_teacher/src/data/views.dart';
import 'package:retrofit/retrofit.dart';

import 'support/test_institute.dart';

/// خادمٌ مصغَّر يطبّق ما يطبّقه `SyncPush` ويبثّ ما يبثّه `change_log`.
///
/// ليس محاكاةً للـ HTTP بل لِعقد المزامنة: `op_uuid` يمنع التكرار، والفتحُ يزرع
/// صفوفَ حضورٍ افتراضية، والجلسةُ تُحسَم بمفتاحها الطبيعي حين لا يطابق المعرّف
/// شيئاً — وهي الحالات الثلاث التي يقوم عليها عملُ التطبيق بلا شبكة.
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

    for (final raw in body['operations'] as List) {
      final op = (raw as Map).cast<String, dynamic>();
      final opUuid = op['op_uuid'] as String;

      if (!_appliedOps.add(opUuid)) {
        skipped.add(opUuid);
        continue;
      }

      switch (op['type']) {
        case 'attendance.session.open':
          _open(op);
        case 'attendance.take':
          _take(op);
        case 'attendance.session.complete':
          _complete(op);
      }

      applied.add(opUuid);
    }

    return _ok({'applied': applied, 'skipped': skipped});
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

  void _take(Map<String, dynamic> op) {
    final key = _sessionKeyFor(op);

    for (final raw in op['attendances'] as List) {
      final row = (raw as Map).cast<String, dynamic>();
      final studentId = studentUuids.entries
          .firstWhere((entry) => entry.value == row['student_uuid'])
          .key;

      _writeAttendance(
        key,
        studentId,
        row['status'] as String,
        // نظير TakeAttendance: المرسَل يغلب، وإلا حُسب من بداية الدوام.
        row['status'] == 'late' ? (row['late_minutes'] as int? ?? 23) : null,
        row['recorded_at'] as String,
        'update',
      );
    }
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
    String operation,
  ) {
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
    _record('attendances', existing == null ? 'create' : operation, row);
  }

  void _record(String table, String operation, Map<String, dynamic> payload) {
    changes.add({
      'server_seq': ++_seq,
      'table_name': table,
      'operation': operation,
      'row_uuid': payload['uuid'],
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
  late TeacherRepository repository;

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
    repository = TeacherRepository(db: db, syncEngine: engine);
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
    expect(offlineView.editable, isFalse);
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
}
