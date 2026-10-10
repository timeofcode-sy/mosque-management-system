import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:retrofit/retrofit.dart';

class _MockApiClient extends Mock implements ApiClient {}

HttpResponse<dynamic> _response(Object? data) =>
    HttpResponse(data, Response(requestOptions: RequestOptions(), data: data));

DioException _offline() => DioException.connectionError(
  requestOptions: RequestOptions(),
  reason: 'no route to host',
);

const _rows = {
  'data': [
    {
      'uuid': 'a1',
      'title': 'اجتماع الأولياء',
      'body': 'نصّ',
      'scope': 'all',
      'audience': ['guardians'],
      'published_at': '2026-10-09T10:00:00Z',
    },
    {
      'uuid': 'a2',
      'title': 'لحلقة ابني',
      'body': 'نصّ',
      'scope': 'circle',
      'audience': ['students', 'guardians'],
      'published_at': null,
    },
  ],
};

/// إعلاناتُ ولي الأمر والأستاذ — ما وُجِّه إليهما فقط، والترشيحُ في الخادم؛ والعميلُ لا يرشّح.
void main() {
  late AppDatabase db;
  late _MockApiClient api;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
  });

  tearDown(() => db.close());

  group('guardian', () {
    test('reads what the server sent without filtering again', () async {
      when(api.guardianAnnouncements).thenAnswer((_) async => _response(_rows));
      final repository = GuardianRepository(db: db, apiClient: api);

      final announcements = (await repository.announcements()).value;

      expect(announcements.map((a) => a.title), [
        'اجتماع الأولياء',
        'لحلقة ابني',
      ]);
      expect(announcements.last.isForMyCircle, isTrue);
      verifyNever(() => api.studentAnnouncements());
    });

    test('a saved copy is served offline and says it is stale', () async {
      when(api.guardianAnnouncements).thenAnswer((_) async => _response(_rows));
      final repository = GuardianRepository(db: db, apiClient: api);
      await repository.announcements();

      when(api.guardianAnnouncements).thenThrow(_offline());

      final snapshot = await repository.announcements();

      expect(snapshot.value, hasLength(2));
      expect(snapshot.isStale, isTrue);
    });
  });

  group('teacher', () {
    test('reads the teacher endpoint, not the student one', () async {
      when(api.teacherAnnouncements).thenAnswer((_) async => _response(_rows));
      final repository = TeacherAnnouncementsRepository(db: db, apiClient: api);

      final announcements = (await repository.announcements()).value;

      expect(announcements, hasLength(2));
      verify(() => api.teacherAnnouncements()).called(1);
      verifyNever(() => api.studentAnnouncements());
      verifyNever(() => api.guardianAnnouncements());
    });

    test('an empty list is empty, not an error, and an outage with nothing saved is raised', () async {
      when(api.teacherAnnouncements)
          .thenAnswer((_) async => _response({'data': <dynamic>[]}));
      final repository = TeacherAnnouncementsRepository(db: db, apiClient: api);

      expect((await repository.announcements()).value, isEmpty);

      final fresh = TeacherAnnouncementsRepository(
        db: AppDatabase(NativeDatabase.memory()),
        apiClient: api,
      );
      when(api.teacherAnnouncements).thenThrow(_offline());

      expect(fresh.announcements(), throwsA(isA<DioException>()));
    });
  });
}
