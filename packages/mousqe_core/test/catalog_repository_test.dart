import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:retrofit/retrofit.dart';

import 'support/test_institute.dart';

class _MockApiClient extends Mock implements ApiClient {}

HttpResponse<dynamic> _ok([dynamic data]) => HttpResponse<dynamic>(
      data ?? const {'data': <String, dynamic>{}},
      Response<dynamic>(requestOptions: RequestOptions(path: '/')),
    );

/// بنيةُ المعهد — ✅ م.6.5: **تُقرأ من drift وتُكتب بـREST**.
///
/// وهذا التركيبُ وحدَه في التطبيق، فما يُقاس هنا طرفاه: أن الكشفَ يُبنى من
/// المخزن المحلي بلا طلبِ شبكةٍ واحد، وأن الكتابةَ تخرج بالشكل الذي يتحقّق منه
/// `CatalogController` — لا في الطابور.
void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late CatalogRepository repository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await TestInstitute.seed(db);
    api = _MockApiClient();
    repository = CatalogRepository(db: db, apiClient: api);
  });

  tearDown(() => db.close());

  group('reading the catalogue', () {
    test('courses carry their shift and circle counts', () async {
      final courses = await repository.loadCourses();
      final current = courses.firstWhere((course) => course.isCurrent);

      expect(current.name, 'دورة 1447');
      expect(current.shiftsCount, greaterThan(0));
      expect(current.circlesCount, greaterThan(0));
      // والدورةُ المنتهية معروضةٌ أيضاً — المشرفُ يهيّئ القادمة ويراجع الماضية.
      expect(courses, hasLength(2));
    });

    test('a shift without seeded days reads as "بلا أيام" not as every day',
        () async {
      final shift = (await repository.loadShifts()).single;

      // الصمتُ ليس «كلَّ الأيام»: دوامٌ بلا `shift_days` لا جلسةَ له، وعرضُه
      // أسبوعاً كاملاً كان يجعل المشرفَ يظنّ الحلقةَ تعمل يومياً.
      expect(shift.weekdays, isEmpty);
      expect(shift.weekdaysLabel, 'بلا أيام');
    });

    test('weekdays arrive from shift_days and read in order', () async {
      await db.into(db.shiftDays).insert(ShiftDaysCompanion.insert(
            uuid: 'sd-2',
            shiftId: 1,
            weekday: 2,
          ));
      await db.into(db.shiftDays).insert(ShiftDaysCompanion.insert(
            uuid: 'sd-0',
            shiftId: 1,
            weekday: 0,
          ));

      final shift = (await repository.loadShifts()).single;

      expect(shift.weekdays, [0, 2]);
      expect(shift.weekdaysLabel, 'الأحد · الثلاثاء');
      expect(shift.timeLabel, startsWith('08:00'));
    });

    test('a defined circle that is not running yet still shows', () async {
      await db.into(db.circles).insert(CirclesCompanion.insert(
            id: const Value(90),
            uuid: 'crc-idle',
            instituteId: 1,
            name: 'حلقة لم تُشغَّل',
          ));

      final circles = await repository.loadCircleDefinitions();
      final idle = circles.firstWhere((circle) => circle.uuid == 'crc-idle');

      // وهي أوّلُ ما يعني المشرف: من يشغّلها في دوامٍ هو هو.
      expect(idle.isRunning, isFalse);
      expect(circles.where((circle) => circle.isRunning), isNotEmpty);
    });

    test('a curriculum item count is read by its own type key', () async {
      await db.into(db.curricula).insert(CurriculaCompanion.insert(
            id: const Value(1),
            uuid: 'cur-mutun',
            name: 'المتون',
            slug: 'mutun',
            type: const Value('mutun'),
            instituteId: const Value(1),
          ));
      await db.into(db.curricula).insert(CurriculaCompanion.insert(
            id: const Value(2),
            uuid: 'cur-quran',
            name: 'القرآن الكريم',
            slug: 'quran',
            type: const Value('quran'),
          ));
      await db.into(db.curriculumItems).insert(CurriculumItemsCompanion.insert(
            uuid: 'itm-bayquniyyah',
            curriculumId: 1,
            name: 'البيقونية',
            code: 'bayquniyyah',
            meta: const Value('{"abyat":34}'),
          ));
      await db.into(db.curriculumItems).insert(CurriculumItemsCompanion.insert(
            uuid: 'itm-juz-30',
            curriculumId: 2,
            name: 'جزء عمّ',
            code: 'juz-30',
            meta: const Value('{"juz":30}'),
          ));

      final curricula = await repository.loadCurricula();
      final mutun = curricula.firstWhere((c) => c.uuid == 'cur-mutun');
      final quran = curricula.firstWhere((c) => c.uuid == 'cur-quran');

      expect(mutun.items.single.count, 34);
      expect(mutun.countLabel, 'عدد الأبيات');
      expect(mutun.isGlobal, isFalse);

      // القرآن بلا عدّادٍ معروض: `juz` واصفةُ بذرةٍ لا عدّادُ حفظ.
      expect(quran.items.single.count, isNull);
      expect(quran.countLabel, isNull);
      // والمزروعُ عامّاً يُعرَف بذلك، فلا يُعرض له زرُّ تحريرٍ يُرفض عند الضغط.
      expect(quran.isGlobal, isTrue);
      expect(quran.isFixedQuran, isTrue);
    });
  });

  group('writing the catalogue', () {
    test('a new shift sends HH:MM and its weekdays', () async {
      when(() => api.createShift(any())).thenAnswer((_) async => _ok());

      await repository.saveShift(
        name: 'الدوام المسائي',
        startsAt: '17:00:00',
        endsAt: '19:30:00',
        weekdays: const [0, 2, 4],
      );

      final body = verify(() => api.createShift(captureAny())).captured.single
          as Map<String, dynamic>;

      // الخادم يتحقّق بـ`date_format:H:i`، فثوانيُ drift تُقتطع قبل الإرسال.
      expect(body['starts_at'], '17:00');
      expect(body['ends_at'], '19:30');
      expect(body['weekdays'], [0, 2, 4]);
    });

    test('editing routes to update, not to a second create', () async {
      when(() => api.updateCircle(any(), any())).thenAnswer((_) async => _ok());

      await repository.saveCircle(uuid: 'crc-1', name: 'حلقة النور');

      verify(() => api.updateCircle('crc-1', any())).called(1);
      verifyNever(() => api.createCircle(any()));
    });

    test('running a circle names the shift it runs in', () async {
      when(() => api.runCircleInCourse(any(), any()))
          .thenAnswer((_) async => _ok());

      await repository.runCircle(
        circleUuid: 'crc-1',
        shiftUuid: 'shf-1',
        room: '  قاعة 2  ',
        capacity: 20,
      );

      final body = verify(() => api.runCircleInCourse('crc-1', captureAny()))
          .captured
          .single as Map<String, dynamic>;

      expect(body['shift_uuid'], 'shf-1');
      expect(body['room'], 'قاعة 2');
      expect(body['capacity'], 20);
    });

    test('a curriculum item goes to the endpoint opened in this phase',
        () async {
      when(() => api.createCurriculumItem(any(), any()))
          .thenAnswer((_) async => _ok());

      await repository.saveCurriculumItem(
        curriculumUuid: 'cur-hadith',
        name: 'الحديث الأول',
        count: 1,
      );

      final body =
          verify(() => api.createCurriculumItem('cur-hadith', captureAny()))
              .captured
              .single as Map<String, dynamic>;

      expect(body['name'], 'الحديث الأول');
      expect(body['count'], 1);
      // والرمزُ متروكٌ للخادم يشتقّه من الترتيب — لا يُخترع هنا.
      expect(body.containsKey('code'), isFalse);
    });

    test('nothing the catalogue writes ever reaches the queue', () async {
      when(() => api.createCourse(any())).thenAnswer((_) async => _ok());

      await repository.saveCourse(
        name: 'دورة 1448',
        startsOn: DateTime(2027, 9, 1),
        status: 'draft',
      );

      // القاعدةُ المُعلَنة في [PHASE-6-STAGES.MD §3.1]: البنيةُ REST لا طابور،
      // وإلا صُفَّت فوقها عشراتُ العمليات ثم رُفض أصلُها فسقط ما فوقه.
      expect(await db.select(db.pendingOperations).get(), isEmpty);
    });
  });
}
