import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';

import 'support/test_institute.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// ملفُّ الطالب عند أستاذه: بطاقتُه (من هو) وجانبُه السلوكي — كلاهما من drift.
void main() {
  late AppDatabase db;
  late CircleRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await TestInstitute.seed(db);
    repository = CircleRepository(
      db: db,
      syncEngine: SyncEngine(
        db: db,
        apiClient: _MockApiClient(),
        app: 'teacher',
        deviceUuid: 'device-1',
      ),
    );

    final ali = (await db.select(db.students).get()).firstWhere(
      (s) => s.id == TestInstitute.ali,
    );
    await db
        .update(db.students)
        .replace(
          ali.copyWith(
            birthDate: Value(DateTime(2013, 5, 7)),
            gradeLevel: const Value('ثامن'),
            studentHealthStatus: const Value('ربو خفيف — بخّاخه معه'),
            currentAddress: const Value('شارع زملكا'),
          ),
        );

    for (final (id, relation, name, alive) in [
      (1, 'father', 'حسن الشامي', false),
      (2, 'mother', 'مريم العلي', true),
    ]) {
      await db
          .into(db.guardians)
          .insert(
            GuardiansCompanion.insert(
              id: Value(id),
              uuid: 'grd-$id',
              instituteId: 1,
              fullName: name,
              phone: const Value('0999249219'),
              isAlive: Value(alive),
            ),
          );
      await db
          .into(db.guardianStudentTable)
          .insert(
            GuardianStudentTableCompanion.insert(
              uuid: 'gs-$id',
              guardianId: id,
              studentId: TestInstitute.ali,
              relation: Value(relation),
            ),
          );
    }

    await db
        .into(db.curricula)
        .insert(
          CurriculaCompanion.insert(
            id: const Value(1),
            uuid: 'cur-q',
            name: 'القرآن',
            slug: 'quran',
          ),
        );
    for (final (id, code, name) in [
      (1, 'juz-29', 'الجزء التاسع والعشرون'),
      (2, 'juz-30', 'الجزء الثلاثون'),
      (3, 'tuhfat-al-atfal', 'تحفة الأطفال'),
    ]) {
      await db
          .into(db.curriculumItems)
          .insert(
            CurriculumItemsCompanion.insert(
              id: Value(id),
              uuid: 'itm-$id',
              curriculumId: 1,
              name: name,
              code: code,
            ),
          );
      await db
          .into(db.studentCurriculumProgressTable)
          .insert(
            StudentCurriculumProgressTableCompanion.insert(
              uuid: 'prg-$id',
              studentId: TestInstitute.ali,
              curriculumItemId: id,
              status: const Value('memorized'),
            ),
          );
    }

    for (final (id, day, note, polarity) in [
      (1, 1, 'يساعد زملاءه في الحفظ', 'positive'),
      (2, 5, 'تحدّث أثناء التسميع', 'negative'),
      (3, 8, null, null),
    ]) {
      await db
          .into(db.attendanceSessions)
          .insert(
            AttendanceSessionsCompanion.insert(
              id: Value(100 + id),
              uuid: 'ses-$id',
              courseCircleId: 1,
              sessionDate: DateTime(2026, 10, day),
            ),
          );
      await db
          .into(db.attendances)
          .insert(
            AttendancesCompanion.insert(
              uuid: 'att-$id',
              attendanceSessionId: 100 + id,
              studentId: TestInstitute.ali,
              note: Value(note),
              notePolarity: Value(polarity),
              recordedAt: DateTime(2026, 10, day, 8),
            ),
          );
    }

    for (final (id, reason, points) in [
      (1, 'behavior', -3.0),
      (2, 'competition', 20.0),
    ]) {
      await db
          .into(db.studentPoints)
          .insert(
            StudentPointsCompanion.insert(
              uuid: 'pts-$id',
              studentId: TestInstitute.ali,
              points: points,
              reason: reason,
              awardedOn: DateTime(2026, 10, 6),
            ),
          );
    }
  });

  tearDown(() => db.close());

  test('the teacher sees who the student is', () async {
    final details = (await repository.loadStudentProfile(TestInstitute.ali))!
        .details;

    expect(details.ageOn(DateTime(2026, 10, 14)), 13);
    expect(details.ageOn(DateTime(2026, 5, 6)), 12);
    expect(details.gradeLevel, 'ثامن');
    expect(details.healthStatus, contains('ربو'));
    expect(details.father!.isAlive, isFalse);
    expect(details.mother!.name, 'مريم العلي');
    expect(details.memorizedJuz, [30, 29]);
    expect(details.otherMemorized, ['تحفة الأطفال']);
  });

  test('the behaviour follows the server rules', () async {
    final behavior = (await repository.loadStudentProfile(TestInstitute.ali))!
        .behavior;

    // الأحدثُ أولاً، والتفقّدُ بلا ملاحظةٍ ليس ملاحظة.
    expect(behavior.notes.map((n) => n.note), [
      'تحدّث أثناء التسميع',
      'يساعد زملاءه في الحفظ',
    ]);
    expect((behavior.positive, behavior.negative, behavior.neutral), (1, 1, 0));
    // نقاطُ المسابقة ليست سلوكاً.
    expect(behavior.points, hasLength(1));
    expect(behavior.behaviorPoints, -3);
  });

  test('the guardian and student payload decodes to the same shape', () {
    final behavior = StudentBehavior.fromJson({
      'summary': {
        'positive': 2,
        'negative': 1,
        'neutral': 0,
        'behavior_points': 5,
      },
      'notes': [
        {
          'date': '2026-10-08',
          'polarity': 'positive',
          'note': 'أحسن',
          'circle': 'النووي',
        },
      ],
      'traits': [
        {'name': 'هادئ', 'polarity': 'positive', 'note': null},
      ],
      'points': [
        {'date': '2026-10-07', 'points': 5, 'note': 'نظّف المصلّى'},
      ],
    });

    expect(behavior.positive, 2);
    expect(behavior.behaviorPoints, 5.0);
    expect(behavior.notes.single.date, DateTime(2026, 10, 8));
    expect(behavior.traits.single.name, 'هادئ');
    expect(behavior.isEmpty, isFalse);
    expect(StudentBehavior.fromJson(const {}).isEmpty, isTrue);
  });
}
