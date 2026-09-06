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
    });
  });
}
