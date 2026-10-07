import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:retrofit/retrofit.dart';

class _MockApiClient extends Mock implements ApiClient {}

HttpResponse<dynamic> _response(Object? data) =>
    HttpResponse(data, Response(requestOptions: RequestOptions(), data: data));

/// انقطاعُ شبكة: `DioException` بلا `ApiException` ملفوف — نظيرُ ما يراه
/// `isOffline` في الإنتاج.
DioException _offline() => DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'no route to host',
    );

/// خطأٌ ردّه الخادم — حالةٌ **معروفة** لا مجهولة، فلا يجوز أن تُقدَّم لقطةٌ مكانه.
DioException _serverError(ApiException wrapped) => DioException(
      requestOptions: RequestOptions(),
      error: wrapped,
      response: Response(requestOptions: RequestOptions(), statusCode: 403),
    );

Map<String, dynamic> _childrenBody() => {
      'data': [
        {
          'uuid': 'std-1',
          'registration_no': '1042',
          'full_name': 'محمد بن خالد',
          'photo_path': null,
          'status': 'active',
        },
      ],
    };

Map<String, dynamic> _attendanceBody({double? todayRate = 100.0}) => {
      'summary': {
        'present': 8,
        'absent': 1,
        'late': 1,
        'excused': 2,
        'total': 12,
        'rate': 90.0,
      },
      'trend': [
        {'date': '2026-09-09', 'rate': todayRate, 'sessions': todayRate == null ? 0 : 1},
        {'date': '2026-09-10', 'rate': null, 'sessions': 0},
      ],
      'recent': [
        {
          'uuid': 'att-1',
          'student_uuid': 'std-1',
          'student_name': 'محمد بن خالد',
          'status': 'late',
          'late_minutes': 12,
          'note': null,
          'recorded_at': '2026-09-10T08:12:44.310000Z',
          'session_date': '2026-09-09',
        },
      ],
    };

void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late GuardianRepository repository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    repository = GuardianRepository(db: db, apiClient: api);
  });

  tearDown(() => db.close());

  group('القراءةُ من الشبكة', () {
    test('children decode the payload and come back fresh', () async {
      when(api.guardianChildren).thenAnswer((_) async => _response(_childrenBody()));

      final snapshot = await repository.children();

      expect(snapshot.value.single.fullName, 'محمد بن خالد');
      expect(snapshot.value.single.status, EntityStatus.active);
      expect(snapshot.isStale, isFalse);
      expect(snapshot.fetchedAt, isNotNull);
    });

    test('a child attendance keeps the day it belongs to, not the day it was written', () async {
      when(() => api.guardianChildAttendance('std-1'))
          .thenAnswer((_) async => _response(_attendanceBody()));

      final snapshot = await repository.attendanceOf('std-1');
      final row = snapshot.value.recent.single;

      // recorded_at في العاشر والجلسةُ في التاسع — تصحيحٌ رجعي، والعرضُ يقرأ
      // sessionDate ([CHECKPOINT-PHASE-7.1.MD §3]).
      expect(row.sessionDate, '2026-09-09');
      expect(row.recordedAt, startsWith('2026-09-10'));
      expect(row.status, AttendanceStatus.late);
      expect(row.lateMinutes, 12);
    });

    /// 🔑 قاعدةُ م.6.6 على سطح العميل: `null` تعني «لم يُقَس» لا «صفر».
    test('a day without a session is unmeasured, not a zero', () async {
      when(() => api.guardianChildAttendance('std-1'))
          .thenAnswer((_) async => _response(_attendanceBody()));

      final trend = (await repository.attendanceOf('std-1')).value.trend;

      expect(trend.first.isMeasured, isTrue);
      expect(trend.first.rate, 100.0);
      expect(trend.last.isMeasured, isFalse);
      expect(trend.last.rate, isNull);
      expect(trend.last.sessions, 0);
    });

    test('progress arrives grouped by the arabic curriculum name', () async {
      when(() => api.guardianChildProgress('std-1')).thenAnswer(
        (_) async => _response({
          'data': {
            'القرآن الكريم': [
              {
                'uuid': 'prg-1',
                'item_name': 'جزء عمّ',
                'item_code': 'juz-30',
                'sort_order': 30,
                'status': 'memorized',
                'status_label': 'محفوظ',
                'percent': 100,
                'score': 92,
                'points': 10,
                'started_on': '2026-07-01',
                'completed_on': '2026-08-20',
                'achieved_on': null,
                'notes': null,
              },
            ],
          },
        }),
      );

      final report = (await repository.progressOf('std-1')).value;

      expect(report.curricula, ['القرآن الكريم']);
      expect(report.isEmpty, isFalse);

      final entry = report.byCurriculum['القرآن الكريم']!.single;
      expect(entry.itemName, 'جزء عمّ');
      expect(entry.status, ProgressStatus.memorized);
      // `json_encode(10.0) === '10'` فيصل العددُ صحيحاً — والنوعُ num يقبلهما.
      expect(entry.points, 10);
    });

    /// 🔴 م.7.4: طالبٌ بلا محفوظاتٍ تخرج خريطتُه من PHP **مصفوفةً `[]`** لا
    /// كائناً. أُصلح العقدُ في الخادم، ويبقى القارئُ متسامحاً فلا يسقط عميلٌ
    /// يتحدّث خادماً أقدم. وهي الحالةُ التي أسقطت الشاشةَ على المحاكي فعلاً.
    test('an empty progress map arrives as a list and is read as empty, not thrown at', () async {
      when(() => api.guardianChildProgress('std-1'))
          .thenAnswer((_) async => _response({'data': <dynamic>[]}));

      final report = (await repository.progressOf('std-1')).value;

      expect(report.isEmpty, isTrue);
      expect(report.curricula, isEmpty);
    });

    test('an excuse carries the staff verdict and its note', () async {
      when(api.guardianExcuses).thenAnswer(
        (_) async => _response({
          'data': [
            {
              'uuid': 'exc-1',
              'student_uuid': 'std-1',
              'student_name': 'محمد بن خالد',
              'from_date': '2026-09-08',
              'to_date': '2026-09-10',
              'reason': 'سفر عائلي',
              'status': 'rejected',
              'status_label': 'مرفوض',
              'reviewed_at': '2026-09-09T07:10:00.000000Z',
              'review_note': 'الدورة في أيامها الأخيرة.',
              'submitted_at': '2026-09-07T19:44:00.000000Z',
            },
          ],
        }),
      );

      final excuse = (await repository.excuses()).value.single;

      expect(excuse.status, ExcuseStatus.rejected);
      expect(excuse.isPending, isFalse);
      expect(excuse.statusLabel, 'مرفوض');
      expect(excuse.reviewNote, 'الدورة في أيامها الأخيرة.');
    });
  });

  group('اللقطةُ عند انقطاع الشبكة', () {
    test('a saved snapshot is served when the network is gone, and says it is stale', () async {
      when(api.guardianChildren).thenAnswer((_) async => _response(_childrenBody()));
      await repository.children();

      when(api.guardianChildren).thenThrow(_offline());

      final snapshot = await repository.children();

      expect(snapshot.value.single.fullName, 'محمد بن خالد');
      expect(snapshot.isStale, isTrue);
      // ومعها تاريخُها — الشاشةُ ملزمةٌ بأن تقول متى قرأت آخرَ مرّة.
      expect(snapshot.fetchedAt, isNotNull);
    });

    test('each child keeps its own snapshot', () async {
      when(() => api.guardianChildAttendance('std-1'))
          .thenAnswer((_) async => _response(_attendanceBody()));
      when(() => api.guardianChildAttendance('std-2'))
          .thenAnswer((_) async => _response(_attendanceBody(todayRate: null)));

      await repository.attendanceOf('std-1');
      await repository.attendanceOf('std-2');

      when(() => api.guardianChildAttendance(any())).thenThrow(_offline());

      // قراءةُ الثاني لم تمحُ لقطةَ الأوّل.
      expect((await repository.attendanceOf('std-1')).value.trend.first.rate, 100.0);
      expect((await repository.attendanceOf('std-2')).value.trend.first.rate, isNull);
    });

    test('with no snapshot at all the outage is raised, not an empty screen', () async {
      when(api.guardianChildren).thenThrow(_offline());

      expect(repository.children(), throwsA(isA<DioException>()));
    });

    /// **ما ليس انقطاعاً لا تُقدَّم لقطةٌ مكانه**: الحسابُ المقفل يجب أن يصل
    /// `SessionController` فيُخرج صاحبَ الجهاز، لا أن يبقى يقرأ لقطةَ أبنائه.
    test('a locked account is raised even when a snapshot exists', () async {
      when(api.guardianChildren).thenAnswer((_) async => _response(_childrenBody()));
      await repository.children();

      when(api.guardianChildren)
          .thenThrow(_serverError(const AccountLockedException()));

      await expectLater(
        repository.children(),
        throwsA(
          isA<DioException>().having(
            (error) => apiExceptionOf(error),
            'الخطأ المصنَّف',
            isA<AccountLockedException>(),
          ),
        ),
      );
    });
  });

  group('تقديمُ الإذن — الكتابةُ الوحيدة', () {
    test('it posts the excuse and returns the pending verdict', () async {
      when(() => api.submitGuardianExcuse(any())).thenAnswer(
        (_) async => _response({'uuid': 'exc-9', 'status': 'pending'}),
      );

      final excuse = await repository.submitExcuse(
        childUuid: 'std-1',
        fromDate: '2026-09-12',
        toDate: '2026-09-13',
        reason: 'سفر عائلي',
      );

      expect(excuse.uuid, 'exc-9');
      expect(excuse.status, ExcuseStatus.pending);

      final sent = verify(() => api.submitGuardianExcuse(captureAny())).captured.single;
      expect(sent, {
        'student_uuid': 'std-1',
        'from_date': '2026-09-12',
        'to_date': '2026-09-13',
        'reason': 'سفر عائلي',
      });
    });

    /// لا طابورَ صامت: الرفضُ يصل الشاشةَ ليقرأه من قدّم الطلب.
    test('a rejected submission is raised, never swallowed into a queue', () async {
      when(() => api.submitGuardianExcuse(any())).thenThrow(
        _serverError(const ValidationException('البيانات غير صحيحة.', {})),
      );

      expect(
        repository.submitExcuse(
          childUuid: 'std-1',
          fromDate: '2026-09-13',
          toDate: '2026-09-12',
          reason: 'مدىً مقلوب',
        ),
        throwsA(isA<DioException>()),
      );
    });

    /// اللقطةُ تُبطَل ولا تُحقَن: استجابةُ `POST` حقلان لا صفٌّ كامل، وحقنُها
    /// كان يضع في القائمة صفّاً بلا اسمِ ابنٍ ولا تاريخ.
    test('submitting invalidates the excuse snapshot instead of patching it', () async {
      when(api.guardianExcuses).thenAnswer((_) async => _response({'data': []}));
      await repository.excuses();

      when(() => api.submitGuardianExcuse(any())).thenAnswer(
        (_) async => _response({'uuid': 'exc-9', 'status': 'pending'}),
      );
      await repository.submitExcuse(
        childUuid: 'std-1',
        fromDate: '2026-09-12',
        toDate: '2026-09-13',
        reason: 'سفر',
      );

      when(api.guardianExcuses).thenThrow(_offline());

      // لا لقطةَ تُقدَّم بعد الإبطال — فلا تُعرض قائمةٌ قديمة لا يظهر فيها ما قُدّم للتوّ.
      expect(repository.excuses(), throwsA(isA<DioException>()));
    });
  });

  /// القرارُ 0.1 مقروءاً من الكود: لا مزامنةَ في هذا الطريق.
  test('the guardian path never touches the sync stream', () async {
    when(api.guardianChildren).thenAnswer((_) async => _response(_childrenBody()));
    when(api.guardianExcuses).thenAnswer((_) async => _response({'data': []}));

    await repository.children();
    await repository.excuses();

    verifyNever(() => api.syncPull(any(), any(), any()));
    verifyNever(() => api.syncPush(any()));
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });
}
