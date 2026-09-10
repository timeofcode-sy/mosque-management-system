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

/// عقدُ مستودع الطالب — م.8.1.
///
/// 🔑 وما يحرسه قبل كل شيء: **أن الرتبة رقمٌ لا كشف**، وأن اللقطة تعمل بلا شبكة.
void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late StudentSelfRepository repository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    repository = StudentSelfRepository(db: db, apiClient: api);
  });

  tearDown(() => db.close());

  group('الرتبة', () {
    test('a standing arrives as a number with no peer rows attached', () async {
      when(api.studentStanding).thenAnswer(
        (_) async => _response({
          'data': {
            'circle_name': 'حلقة أبي بن كعب',
            'rank': 5,
            'peers': 20,
            'rate': 87.5,
            'points': 42,
          },
        }),
      );

      final standing = (await repository.standing()).value;

      expect(standing.circleName, 'حلقة أبي بن كعب');
      expect(standing.rank, 5);
      expect(standing.peers, 20);
      expect(standing.isRanked, isTrue);
      expect(standing.points, 42);
    });

    /// 🔑 قاعدةُ م.6.6 على سطح الطالب: `null` تعني «لم يُقَس» لا «الأخير».
    test('an unmeasured standing is unranked, not last', () async {
      when(api.studentStanding).thenAnswer(
        (_) async => _response({
          'data': {'circle_name': 'حلقة أبي بن كعب', 'rank': null, 'peers': 20, 'rate': null, 'points': 0},
        }),
      );

      final standing = (await repository.standing()).value;

      expect(standing.isRanked, isFalse);
      expect(standing.rank, isNull);
      expect(standing.rate, isNull);
      // وعددُ الزملاء يبقى معروفاً — «لم تُقَس بعد بين عشرين» جملةٌ مفهومة.
      expect(standing.peers, 20);
    });
  });

  group('النقاط', () {
    test('the five sources arrive, and whole numbers survive as num', () async {
      when(api.studentPoints).thenAnswer(
        (_) async => _response({
          'data': {'quran': 10, 'hadith': 5, 'mutun': 0, 'attendance': 12.5, 'manual': 3, 'total': 30.5},
        }),
      );

      final points = (await repository.points()).value;

      // `json_encode(10.0) === '10'` — والنوعُ num يقبل الشكلين.
      expect(points.quran, 10);
      expect(points.attendance, 12.5);
      expect(points.total, 30.5);
    });

    test('a payload with missing sources falls back to zero, not to an error', () async {
      when(api.studentPoints).thenAnswer((_) async => _response({'data': <String, dynamic>{}}));

      expect((await repository.points()).value.total, 0);
    });
  });

  group('الإعلانات', () {
    test('an announcement says whether it was aimed at the circle', () async {
      when(api.studentAnnouncements).thenAnswer(
        (_) async => _response({
          'data': [
            {'uuid': 'a1', 'title': 'مسابقة', 'body': 'نصّ', 'scope': 'circle', 'published_at': '2026-09-09T10:00:00Z'},
            {'uuid': 'a2', 'title': 'دوام', 'body': 'نصّ', 'scope': 'all', 'published_at': null},
          ],
        }),
      );

      final announcements = (await repository.announcements()).value;

      expect(announcements, hasLength(2));
      expect(announcements.first.isForMyCircle, isTrue);
      expect(announcements.last.isForMyCircle, isFalse);
    });

    test('an empty list is empty, not an error', () async {
      when(api.studentAnnouncements).thenAnswer((_) async => _response({'data': <dynamic>[]}));

      expect((await repository.announcements()).value, isEmpty);
    });
  });

  group('اللقطةُ عند انقطاع الشبكة', () {
    test('a saved standing is served offline and says it is stale', () async {
      when(api.studentStanding).thenAnswer(
        (_) async => _response({
          'data': {'circle_name': 'حلقتي', 'rank': 3, 'peers': 12, 'rate': 91.0, 'points': 7},
        }),
      );
      await repository.standing();

      when(api.studentStanding).thenThrow(_offline());

      final snapshot = await repository.standing();

      expect(snapshot.value.rank, 3);
      expect(snapshot.isStale, isTrue);
      expect(snapshot.fetchedAt, isNotNull);
    });

    test('with nothing saved the outage is raised', () async {
      when(api.studentPoints).thenThrow(_offline());

      expect(repository.points(), throwsA(isA<DioException>()));
    });
  });

  /// القرارُ 1.1 مقروءاً من الكود: لا تيّارَ ولا طابور في طريق الطالب.
  test('the student path never touches the sync stream nor the queue', () async {
    when(api.studentAttendance).thenAnswer(
      (_) async => _response({'summary': <String, dynamic>{}, 'trend': [], 'recent': []}),
    );
    when(api.studentAnnouncements).thenAnswer((_) async => _response({'data': <dynamic>[]}));

    await repository.attendance();
    await repository.announcements();

    verifyNever(() => api.syncPull(any(), any(), any()));
    verifyNever(() => api.syncPush(any()));
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });
}
