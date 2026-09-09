import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';

import 'support/test_institute.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// الإدارةُ اليومية أوف-لاين — ✅ م.6.5.
///
/// وما يُقاس هنا **العقدُ لا الشاشة**: أن تُقرأ الاستمارةُ كاملةً من drift، وأن
/// يخرج منها إلى الطابور ما يفهمه `SyncPush` بالضبط — مراجعُ `uuid` لا مفاتيحَ
/// أساسية، وطالبٌ وتسجيلُه في **دفعةٍ واحدة**.
void main() {
  late AppDatabase db;
  late SyncEngine engine;
  late StudentRepository repository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await TestInstitute.seed(db);
    engine = SyncEngine(
      db: db,
      apiClient: _MockApiClient(),
      app: 'admin_desktop',
      deviceUuid: 'device-desktop',
    );
    repository = StudentRepository(db: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> queue() async {
    final rows = await (db.select(db.pendingOperations)
          ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
        .get();

    return [
      for (final row in rows)
        {'type': row.type, ...jsonDecode(row.payload) as Map<String, dynamic>},
    ];
  }

  /// الاستمارةُ كاملةً في drift: صفاتٌ ومنهجٌ وواصفةٌ ووليّان.
  Future<void> seedFormData() async {
    await db.into(db.personalTraits).insert(PersonalTraitsCompanion.insert(
          id: const Value(1),
          uuid: 'trt-calm',
          name: 'هادئ',
          slug: 'calm',
        ));
    await db.into(db.personalTraits).insert(PersonalTraitsCompanion.insert(
          id: const Value(2),
          uuid: 'trt-shy',
          name: 'خجول',
          slug: 'shy',
          // صفةٌ خاصّةٌ بالمعهد إلى جانب العامّة — والشاشةُ تعرض الاثنتين.
          instituteId: const Value(1),
        ));

    await db.into(db.curricula).insert(CurriculaCompanion.insert(
          id: const Value(1),
          uuid: 'cur-quran',
          name: 'القرآن الكريم',
          slug: 'quran',
          type: const Value('quran'),
        ));
    await db.into(db.curriculumItems).insert(CurriculumItemsCompanion.insert(
          id: const Value(1),
          uuid: 'itm-juz-30',
          curriculumId: 1,
          name: 'جزء عمّ',
          code: 'juz-30',
        ));

    await db.into(db.customFields).insert(CustomFieldsCompanion.insert(
          id: const Value(1),
          uuid: 'fld-bus',
          instituteId: 1,
          entity: 'student',
          key: 'bus_line',
          label: 'خط الحافلة',
        ));
    // واصفةُ أستاذٍ لا تظهر في استمارة الطالب.
    await db.into(db.customFields).insert(CustomFieldsCompanion.insert(
          id: const Value(2),
          uuid: 'fld-teacher',
          instituteId: 1,
          entity: 'teacher',
          key: 'degree',
          label: 'الشهادة',
        ));
  }

  group('the registration form', () {
    test('reads back whole from drift, not the eight display columns', () async {
      await seedFormData();

      // طالبٌ وصل من الخادم باستمارته كاملةً.
      await db.update(db.students).replace(
            (await db.select(db.students).get())
                .firstWhere((row) => row.id == TestInstitute.ali)
                .copyWith(
                  registrationNo: const Value('S-101'),
                  gradeLevel: const Value('الصف السابع'),
                  permanentAddress: const Value('حي النزهة'),
                  studentHealthStatus: const Value('سليم'),
                  notes: const Value('يحتاج متابعةً في التجويد'),
                  familyMembersCount: const Value(6),
                ),
          );

      await db.into(db.guardians).insert(GuardiansCompanion.insert(
            id: const Value(1),
            uuid: 'grd-1',
            instituteId: 1,
            fullName: 'أحمد بن سالم',
            occupation: const Value('مهندس'),
            phone: const Value('0500000000'),
          ));
      await db.into(db.guardianStudentTable).insert(
            GuardianStudentTableCompanion.insert(
              uuid: 'gs-1',
              guardianId: 1,
              studentId: TestInstitute.ali,
              relation: const Value('father'),
            ),
          );

      await db.into(db.studentTraitTable).insert(
            StudentTraitTableCompanion.insert(
              uuid: 'st-1',
              studentId: TestInstitute.ali,
              traitId: 1,
            ),
          );

      await db.into(db.studentCurriculumProgressTable).insert(
            StudentCurriculumProgressTableCompanion.insert(
              uuid: 'prg-1',
              studentId: TestInstitute.ali,
              curriculumItemId: 1,
              status: const Value('memorized'),
            ),
          );

      await db.into(db.customFieldValues).insert(
            CustomFieldValuesCompanion.insert(
              uuid: 'cfv-1',
              customFieldId: 1,
              entityType: 'App\\Models\\Student',
              entityId: TestInstitute.ali,
              value: const Value('"خط 4"'),
            ),
          );

      final form = (await repository.loadStudentForm('stu-ali'))!;

      expect(form.registrationNo, 'S-101');
      expect(form.gradeLevel, 'الصف السابع');
      expect(form.permanentAddress, 'حي النزهة');
      expect(form.studentHealthStatus, 'سليم');
      expect(form.notes, 'يحتاج متابعةً في التجويد');
      expect(form.familyMembersCount, 6);
      expect(form.father.fullName, 'أحمد بن سالم');
      expect(form.father.occupation, 'مهندس');
      expect(form.mother.isEmpty, isTrue);
      expect(form.traitUuids, {'trt-calm'});
      expect(form.memorizedItemUuids, {'itm-juz-30'});
      // قيمةُ الواصفة تصل نصَّ JSON، والمعروضُ ما بداخلها لا ترميزُها.
      expect(form.customFields, {'fld-bus': 'خط 4'});
      // وحلقتُه الجارية تُقرأ من التسجيل الفعّال لا من آخر صفٍّ في الجدول.
      expect(form.courseCircleUuid, TestInstitute.circleUuid);
    });

    test('a new student and the enrolment ride the same batch', () async {
      final uuid = await repository.saveStudent(const StudentForm(
        firstName: 'يوسف',
        fatherName: 'عمر',
        familyName: 'الحربي',
        courseCircleUuid: TestInstitute.circleUuid,
        traitUuids: {'trt-calm'},
        memorizedItemUuids: {'itm-juz-30'},
      ));

      final operations = await queue();

      expect(operations, hasLength(1));
      expect(operations.single['type'], 'student.save');
      // المعرّفُ يولّده العميل، فلا ينتظر أحدٌ ردَّ الخادم ليسجّل الطالبَ في حلقة.
      expect(operations.single['uuid'], uuid);
      expect(operations.single['course_circle_uuid'], TestInstitute.circleUuid);
      // والمراجعُ بالـ`uuid` لا بالمفتاح الأساسي — الجهازُ لا يعرف الأرقامَ أصلاً.
      expect(operations.single['trait_uuids'], ['trt-calm']);
      expect(operations.single['memorized_item_uuids'], ['itm-juz-30']);
    });

    test('editing keeps the uuid so it updates instead of duplicating', () async {
      await repository.saveStudent(const StudentForm(
        uuid: 'stu-ali',
        firstName: 'علي',
        fatherName: 'حسن',
        familyName: 'الشامي',
        status: 'graduated',
      ));

      final operations = await queue();

      expect(operations.single['uuid'], 'stu-ali');
      expect(
        (operations.single['student'] as Map)['status'],
        'graduated',
      );
    });

    test('an empty guardian is not sent as a nameless row', () async {
      await repository.saveStudent(const StudentForm(
        firstName: 'يوسف',
        fatherName: 'عمر',
        familyName: 'الحربي',
        father: GuardianDraft(fullName: 'عمر الحربي'),
        // الأمُّ متروكةٌ فارغةً — وإرسالُها كان يعني صفَّ وليٍّ بلا اسم.
      ));

      final guardians =
          (await queue()).single['guardians'] as Map<String, dynamic>;

      expect(guardians.keys, ['father']);
    });

    test('a queued student is flagged in the roster before it lands', () async {
      await repository.saveStudent(const StudentForm(
        uuid: 'stu-ali',
        firstName: 'علي',
        fatherName: 'حسن',
        familyName: 'الشامي',
      ));

      final entry = (await repository.loadStudents())
          .firstWhere((student) => student.uuid == 'stu-ali');

      // وإلا بدا للمشرف أن حفظَه ضاع، فأعاده — فصُفَّ الطالبُ مرّتين.
      expect(entry.pending, isTrue);
    });

    test('the roster shows each student current circle', () async {
      final entry = (await repository.loadStudents())
          .firstWhere((student) => student.id == TestInstitute.ali);

      expect(entry.circleName, isNotNull);
      expect(entry.fullName, contains('علي'));
    });
  });

  group('enrolment and transfer', () {
    test('a transfer names the destination and the reason', () async {
      await repository.transferStudent(
        studentUuid: 'stu-ali',
        toCourseCircleUuid: TestInstitute.otherCircleUuid,
        reason: 'انتقل إلى مستوى أعلى',
      );

      final operation = (await queue()).single;

      expect(operation['type'], 'student.transfer');
      expect(operation['to_course_circle_uuid'], TestInstitute.otherCircleUuid);
      expect(operation['reason'], 'انتقل إلى مستوى أعلى');
    });

    test('a blank reason is omitted rather than sent empty', () async {
      await repository.transferStudent(
        studentUuid: 'stu-ali',
        toCourseCircleUuid: TestInstitute.otherCircleUuid,
        reason: '   ',
      );

      expect((await queue()).single.containsKey('reason'), isFalse);
    });

    test('enrolling an existing student is its own operation', () async {
      await repository.enrollStudent(
        studentUuid: 'stu-badr',
        courseCircleUuid: TestInstitute.otherCircleUuid,
      );

      final operation = (await queue()).single;

      expect(operation['type'], 'enrollment.save');
      expect(operation['student_uuid'], 'stu-badr');
    });
  });

  group('absence excuses', () {
    setUp(() async {
      await db.into(db.absenceExcusesTable).insert(
            AbsenceExcusesTableCompanion.insert(
              uuid: 'exc-1',
              studentId: TestInstitute.ali,
              fromDate: DateTime(2026, 9, 20),
              toDate: DateTime(2026, 9, 22),
              reason: 'سفر مع العائلة',
            ),
          );
    });

    test('a pending excuse carries the student name', () async {
      final excuse = (await repository.loadExcuses()).single;

      expect(excuse.isPending, isTrue);
      expect(excuse.studentName, contains('علي'));
      expect(excuse.pending, isFalse);
    });

    test('a queued decision shows at once and is marked unsent', () async {
      await repository.reviewExcuse(
        excuseUuid: 'exc-1',
        approve: true,
        note: 'إذن مقبول',
      );

      final excuse = (await repository.loadExcuses()).single;

      // القرارُ يظهر قبل أن يصل الخادمَ — وإلا ضغط المشرفُ ثانيةً فصُفَّ حكمان.
      expect(excuse.status, 'approved');
      expect(excuse.pending, isTrue);

      final operation = (await queue()).single;

      expect(operation['type'], 'excuse.review');
      expect(operation['decision'], 'approved');
      expect(operation['note'], 'إذن مقبول');
    });

    test('a rejection is a decision too, never a silent no-op', () async {
      await repository.reviewExcuse(excuseUuid: 'exc-1', approve: false);

      expect((await queue()).single['decision'], 'rejected');
    });
  });

  group('the form catalogue', () {
    test('traits are the global ones and the institute own together', () async {
      await seedFormData();

      final traits = await repository.loadTraits();

      expect(traits.map((trait) => trait.uuid), containsAll(['trt-calm', 'trt-shy']));
    });

    test('only student custom fields reach the student form', () async {
      await seedFormData();

      final fields = await repository.loadStudentCustomFields();

      expect(fields.map((field) => field.uuid), ['fld-bus']);
    });
  });
}
