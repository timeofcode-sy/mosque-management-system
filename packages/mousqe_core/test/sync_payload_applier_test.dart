import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/src/db/database.dart';
import 'package:mousqe_core/src/sync/sync_payload_applier.dart';

void main() {
  late AppDatabase db;
  late SyncPayloadApplier applier;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    applier = SyncPayloadApplier(db);
  });

  tearDown(() => db.close());

  test('create inserts a new row matched by uuid', () async {
    await applier.apply(
      tableName: 'students',
      operation: 'create',
      rowUuid: 'stu-1',
      payload: {
        'uuid': 'stu-1',
        'institute_id': 1,
        'registration_no': '1001',
        'photo_path': null,
        'first_name': 'محمد',
        'father_name': 'خالد',
        'family_name': 'المصري',
        'status': 'active',
      },
    );

    final row = await (db.select(db.students)..where((t) => t.uuid.equals('stu-1'))).getSingle();
    expect(row.firstName, 'محمد');
    expect(row.instituteId, 1);
  });

  test('update on an existing uuid replaces the row not duplicates it', () async {
    final payload = {
      'uuid': 'stu-1',
      'institute_id': 1,
      'registration_no': '1001',
      'photo_path': null,
      'first_name': 'محمد',
      'father_name': 'خالد',
      'family_name': 'المصري',
      'status': 'active',
    };
    await applier.apply(tableName: 'students', operation: 'create', rowUuid: 'stu-1', payload: payload);

    await applier.apply(
      tableName: 'students',
      operation: 'update',
      rowUuid: 'stu-1',
      payload: {...payload, 'status': 'inactive'},
    );

    final rows = await db.select(db.students).get();
    expect(rows, hasLength(1));
    expect(rows.single.status, 'inactive');
  });

  test('delete removes the row matched by uuid with no payload', () async {
    await applier.apply(
      tableName: 'students',
      operation: 'create',
      rowUuid: 'stu-1',
      payload: {
        'uuid': 'stu-1',
        'institute_id': 1,
        'registration_no': '1001',
        'photo_path': null,
        'first_name': 'محمد',
        'father_name': 'خالد',
        'family_name': 'المصري',
        'status': 'active',
      },
    );

    await applier.apply(tableName: 'students', operation: 'delete', rowUuid: 'stu-1');

    final rows = await db.select(db.students).get();
    expect(rows, isEmpty);
  });

  test('an eloquent boolean cast arrives as true not 1', () async {
    // `is_active` عليه cast 'boolean' في النموذج، فـ`toArray()` يعطي true لا 1 —
    // وقراءتُه `as int?` كانت ترمي TypeError على أوّل صفّ معهدٍ يصل من الخادم.
    await applier.apply(
      tableName: 'institutes',
      operation: 'create',
      rowUuid: 'ins-1',
      payload: {
        'uuid': 'ins-1',
        'name': 'معهد النور',
        'short_name': null,
        'logo_path': null,
        'settings': {
          'theme': {'primary': '#7d0a0a', 'secondary': '#ffbf9b', 'surface': '#ead196'},
        },
        'is_active': true,
      },
    );

    final row = await db.select(db.institutes).getSingle();
    expect(row.isActive, isTrue);

    // و`settings` عليه cast 'array' فيصل كائناً — يُخزَّن JSON لا صيغةَ Dart،
    // وإلا فشل `jsonDecode` عند قراءة ثيم المعهد أوف-لاين.
    final settings = jsonDecode(row.settings!) as Map<String, dynamic>;
    expect((settings['theme'] as Map)['primary'], '#7d0a0a');
  });

  test('an enrollment carries the dates that bound a backdated take', () async {
    await applier.apply(
      tableName: 'enrollments',
      operation: 'create',
      rowUuid: 'enr-1',
      payload: {
        'uuid': 'enr-1',
        'course_circle_id': 3,
        'student_id': 7,
        'status': 'active',
        'enrolled_on': '2026-09-01',
        'left_on': null,
      },
    );

    final row = await db.select(db.enrollments).getSingle();
    expect(row.courseCircleId, 3);
    expect(row.enrolledOn, DateTime(2026, 9, 1));
    expect(row.leftOn, isNull);
  });

  test('a shift keeps its start time verbatim for LateMinutes', () async {
    await applier.apply(
      tableName: 'shifts',
      operation: 'create',
      rowUuid: 'shf-1',
      payload: {
        'uuid': 'shf-1',
        'course_id': 2,
        'name': 'الدوام الصباحي',
        'starts_at': '08:00:00',
        'ends_at': '10:30:00',
        'sort_order': 1,
        'is_active': true,
      },
    );

    expect((await db.select(db.shifts).getSingle()).startsAt, '08:00:00');
  });

  test('a table with no local store is ignored not thrown at', () async {
    // السحب معهدٌ كامل: تصل صفوفُ جداول لا شاشة تقرؤها (evaluations، tags…).
    await applier.apply(
      tableName: 'evaluations',
      operation: 'create',
      rowUuid: 'ev-1',
      payload: {'uuid': 'ev-1'},
    );

    await applier.apply(tableName: 'evaluations', operation: 'delete', rowUuid: 'ev-1');
  });

  test('the server primary key is kept so foreign keys still resolve', () async {
    // الحمولة تحمل مفاتيح أجنبية بمعرّفات الخادم الرقمية. لو تُرك `id` لعدّاد
    // drift لَحملت الجلسةُ id محلياً وحملت صفوفُ حضورها attendance_session_id
    // خادمياً — فلا يلتقيان، ويبقى الكشف فارغاً في التطبيق بلا خطأٍ ظاهر.
    await applier.apply(
      tableName: 'attendance_sessions',
      operation: 'create',
      rowUuid: 'ses-1',
      payload: {
        'id': 412,
        'uuid': 'ses-1',
        'course_circle_id': 9,
        'session_date': '2026-09-15',
        'status': 'draft',
        'completed_at': null,
      },
    );

    await applier.apply(
      tableName: 'attendances',
      operation: 'create',
      rowUuid: 'att-1',
      payload: {
        'id': 900,
        'uuid': 'att-1',
        'attendance_session_id': 412,
        'student_id': 7,
        'status': 'present',
        'late_minutes': null,
        'note': null,
        'note_polarity': null,
        'recorded_at': '2026-09-15T05:05:00.000000Z',
      },
    );

    final session = await db.select(db.attendanceSessions).getSingle();
    final attendance = await db.select(db.attendances).getSingle();

    expect(session.id, 412);
    expect(attendance.attendanceSessionId, session.id);
  });
}
