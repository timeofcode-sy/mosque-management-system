import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/src/api/api_client.dart';
import 'package:mousqe_core/src/db/database.dart';
import 'package:mousqe_core/src/sync/sync_engine.dart';
import 'package:retrofit/retrofit.dart';

class _MockApiClient extends Mock implements ApiClient {}

HttpResponse<dynamic> _response(Map<String, dynamic> data) {
  return HttpResponse(data, Response(requestOptions: RequestOptions(), data: data));
}

void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late SyncEngine engine;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    engine = SyncEngine(db: db, apiClient: api, app: 'teacher', deviceUuid: 'device-1');
  });

  tearDown(() => db.close());

  group('push', () {
    test('repeating the same op_uuid produces no duplicate effect', () async {
      final opUuid = await engine.enqueue('attendance.session.open', {
        'course_circle_uuid': 'circle-1',
      });

      when(() => api.syncPush(any())).thenAnswer(
        (_) async => _response({
          'applied': [],
          'skipped': [opUuid],
        }),
      );

      await engine.push();
      await engine.push();

      final remaining = await db.select(db.pendingOperations).get();
      expect(remaining, isEmpty);
      verify(() => api.syncPush(any())).called(1);
    });

    test('a missing response leaves the operation queued for retry', () async {
      await engine.enqueue('attendance.session.open', {
        'course_circle_uuid': 'circle-1',
      });

      when(() => api.syncPush(any())).thenThrow(
        DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionTimeout),
      );

      await engine.push();

      final remaining = await db.select(db.pendingOperations).get();
      expect(remaining, hasLength(1));
    });

    test('the batch carries the device uuid the server resolves conflicts with', () async {
      await engine.enqueue('attendance.session.open', {'course_circle_uuid': 'c1'});

      Map<String, dynamic>? sent;
      when(() => api.syncPush(any())).thenAnswer((invocation) async {
        sent = invocation.positionalArguments.first as Map<String, dynamic>;
        return _response({'applied': <String>[], 'skipped': <String>[]});
      });

      await engine.push();

      // بدونه لا يميّز ResolveAttendanceConflicts «كتابتي» من «كتابة غيري»
      // (SYNC-PROTOCOL §5)، ويبقى last_pushed_at فارغاً في شاشة الأجهزة.
      expect(sent!['device_uuid'], 'device-1');
    });

    test('applied and skipped operations are both removed from the queue', () async {
      final opA = await engine.enqueue('attendance.session.open', {'course_circle_uuid': 'c1'});
      final opB = await engine.enqueue('attendance.session.complete', {'session_uuid': 's1'});

      when(() => api.syncPush(any())).thenAnswer(
        (_) async => _response({
          'applied': [opA],
          'skipped': [opB],
        }),
      );

      await engine.push();

      final remaining = await db.select(db.pendingOperations).get();
      expect(remaining, isEmpty);
    });
  });

  // ── عزلُ العملية المرفوضة ✅ م.6.2 — [SYNC-PROTOCOL.md §3] البند 4 ───────────
  group('failed[]', () {
    test('a rejected operation is quarantined, not deleted and not resent', () async {
      final poison = await engine.enqueue('attendance.session.complete', {'session_uuid': 's-gone'});
      final good = await engine.enqueue('points.award', {'student_uuid': 'stu-1'});

      when(() => api.syncPush(any())).thenAnswer(
        (_) async => _response({
          'applied': [good],
          'skipped': <String>[],
          'failed': [
            {'op_uuid': poison, 'message': 'صفٌّ تقصده العملية غير موجود في هذا المعهد.'},
          ],
        }),
      );

      await engine.push();

      // لا تُحذف: حذفُها ضياعُ كتابةٍ لم يعرف بها صاحبُها.
      final row = await (db.select(db.pendingOperations)..where((t) => t.opUuid.equals(poison))).getSingle();
      expect(row.failedReason, 'صفٌّ تقصده العملية غير موجود في هذا المعهد.');
      expect(row.failedAt, isNotNull);

      // ولا تُرسَل ثانيةً: دفعةٌ تالية بلا معلَّقٍ سليم لا تلمس الشبكة أصلاً.
      await engine.push();
      verify(() => api.syncPush(any())).called(1);
    });

    test('the pending counter ignores what is quarantined', () async {
      final poison = await engine.enqueue('attendance.take', {'session_uuid': 's-gone'});

      when(() => api.syncPush(any())).thenAnswer(
        (_) async => _response({
          'applied': <String>[],
          'skipped': <String>[],
          'failed': [
            {'op_uuid': poison, 'message': 'الجلسة مقفلة.'},
          ],
        }),
      );

      await engine.push();

      // «٣ عمليات بانتظار المزامنة» رقمٌ ينتظر صاحبُه أن يبلغ صفراً — والمعزولةُ
      // لها عدّادُها ورسالتُها.
      expect(await engine.watchPendingCount().first, 0);
      expect(await engine.watchFailedOperations().first, hasLength(1));
    });

    test('a human decision either retries it or throws it away', () async {
      final poison = await engine.enqueue('student.save', {'uuid': 'stu-9'});

      when(() => api.syncPush(any())).thenAnswer(
        (_) async => _response({
          'applied': <String>[],
          'skipped': <String>[],
          'failed': [
            {'op_uuid': poison, 'message': 'لا تملك صلاحية «students.manage».'},
          ],
        }),
      );
      await engine.push();

      // إعادةُ المحاولة ترفع العزل — بنفس op_uuid، فالخادم يبقى مانعاً للتكرار.
      await engine.retryFailed(poison);
      expect(await engine.watchPendingCount().first, 1);
      expect(await engine.watchFailedOperations().first, isEmpty);

      await engine.push();
      final row = await (db.select(db.pendingOperations)..where((t) => t.opUuid.equals(poison))).getSingle();
      expect(row.failedReason, isNotNull);

      // والتخلّي عنها هو الطريق الوحيد لحذفها.
      await engine.discardFailed(poison);
      expect(await db.select(db.pendingOperations).get(), isEmpty);
    });

    test('an old server that never sends failed[] keeps working unchanged', () async {
      final opUuid = await engine.enqueue('points.award', {'student_uuid': 'stu-1'});

      when(() => api.syncPush(any()))
          .thenAnswer((_) async => _response({'applied': [opUuid], 'skipped': <String>[]}));

      await engine.push();

      expect(await db.select(db.pendingOperations).get(), isEmpty);
    });
  });

  group('pull', () {
    test('repeats until an empty page is returned', () async {
      var call = 0;
      when(() => api.syncPull(any(), any(), any())).thenAnswer((_) async {
        call += 1;
        if (call == 1) {
          return _response({
            'server_seq': 10,
            'changes': [
              {
                'table_name': 'students',
                'operation': 'create',
                'row_uuid': 'stu-1',
                'payload': {
                  'uuid': 'stu-1',
                  'institute_id': 1,
                  'registration_no': '1',
                  'photo_path': null,
                  'first_name': 'أ',
                  'father_name': 'ب',
                  'family_name': 'ج',
                  'status': 'active',
                },
              },
            ],
          });
        }
        if (call == 2) {
          return _response({
            'server_seq': 15,
            'changes': [
              {
                'table_name': 'students',
                'operation': 'create',
                'row_uuid': 'stu-2',
                'payload': {
                  'uuid': 'stu-2',
                  'institute_id': 1,
                  'registration_no': '2',
                  'photo_path': null,
                  'first_name': 'د',
                  'father_name': 'هـ',
                  'family_name': 'و',
                  'status': 'active',
                },
              },
            ],
          });
        }
        return _response({'server_seq': 15, 'changes': []});
      });

      await engine.pull();

      expect(call, 3);
      final students = await db.select(db.students).get();
      expect(students, hasLength(2));

      final state = await db.select(db.syncState).getSingle();
      expect(state.lastPulledSeq, 15);
      expect(state.lastPulledAt, isNotNull);
    });

    test('a quiet institute still stamps the last successful pull', () async {
      when(() => api.syncPull(any(), any(), any()))
          .thenAnswer((_) async => _response({'server_seq': 0, 'changes': []}));

      await engine.pull();

      // لا صفَّ sync_state يُكتب حين لا تغييرات، فالختمُ تحديثاً وحده كان يترك
      // «آخر سحب ناجح» فارغاً إلى الأبد على معهدٍ لم يتغيّر فيه شيء.
      expect(await engine.watchLastPulledAt().first, isNotNull);
    });
  });

  group('watchPendingCount', () {
    test('follows the queue as operations are enqueued and confirmed', () async {
      expect(await engine.watchPendingCount().first, 0);

      final opUuid = await engine.enqueue('points.award', {'student_uuid': 'stu-1'});
      expect(await engine.watchPendingCount().first, 1);

      when(() => api.syncPush(any()))
          .thenAnswer((_) async => _response({'applied': [opUuid], 'skipped': <String>[]}));
      await engine.push();

      expect(await engine.watchPendingCount().first, 0);
    });
  });
}
