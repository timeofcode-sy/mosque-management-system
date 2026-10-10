import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_admin_desktop/src/di/app_scope.dart';
import 'package:mousqe_admin_desktop/src/screens/catalog_screen.dart';
import 'package:mousqe_admin_desktop/src/screens/curricula_screen.dart';
import 'package:mousqe_admin_desktop/src/screens/excuses_screen.dart';
import 'package:mousqe_admin_desktop/src/screens/student_form_screen.dart';
import 'package:mousqe_admin_desktop/src/screens/students_screen.dart';
import 'package:mousqe_admin_desktop/src/state/institute_switcher.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:retrofit/retrofit.dart';

import 'support/snapshots.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MemoryTokenStore implements TokenStore {
  String? token = '12|secret';

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String> deviceUuid() async => 'device-1';
}

HttpResponse<dynamic> _response(Object? data) =>
    HttpResponse(data, Response(requestOptions: RequestOptions(), data: data));

/// شاشاتُ الإدارة اليومية وسطحِ الإدارة — ✅ م.6.5.
///
/// وما يُقاس هنا هو نفسُ ما قاسته م.6.3 في القائمة الجانبية وم.6.4 في شاشة
/// التفقّد، **داخلَ الأبواب الجديدة**: أن الواجهة تُبنى على `user.permissions`،
/// وأن **ما لا يملكه المستخدم لا يظهر أصلاً** — لا معطَّلاً ولا برسالةِ رفضٍ عند
/// الضغط. ونفسُ الشيفرة، ولقطتان.
void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late AppDependencies dependencies;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
  });

  tearDown(() => db.close());

  Future<void> boot(List<String> permissions) async {
    final tokens = _MemoryTokenStore();
    final engine = SyncEngine(
      db: db,
      apiClient: api,
      app: 'admin_desktop',
      deviceUuid: 'device-1',
    );
    final session = SessionController(
      db: db,
      apiClient: api,
      tokenStore: tokens,
      deviceUuid: 'device-1',
      app: 'admin_desktop',
      appLabel: 'إدارة المعهد',
      activeInstitute: ActiveInstitute(),
    );
    final sync = SyncController(engine: engine, session: session);

    when(() => api.bootstrap()).thenAnswer(
      (_) async => _response(bootstrapBody(permissions: permissions)),
    );

    dependencies = AppDependencies(
      endpoint: ServerEndpoint(fallbackBaseUrl: 'http://test.invalid/api/v1'),
      db: db,
      tokenStore: tokens,
      apiClient: api,
      syncEngine: engine,
      session: session,
      sync: sync,
      institutes: InstituteSwitcher(session: session, sync: sync),
      circles: CircleRepository(db: db, syncEngine: engine),
      students: StudentRepository(db: db, syncEngine: engine),
      catalog: CatalogRepository(db: db, apiClient: api),
      admin: AdminRepository(apiClient: api),
      stats: StatsRepository(db: db),
      conflicts: ConflictRepository(apiClient: api),
    );

    await session.restore();
  }

  /// معهدٌ بدورةٍ جارية وحلقةٍ وطالبٍ مسجَّل — كما يصل في `sync/pull`.
  Future<void> seed() async {
    await db.into(db.institutes).insert(
          InstitutesCompanion.insert(
            id: const Value(1),
            uuid: 'ins-1',
            name: 'معهد النور',
          ),
        );
    await db.into(db.courses).insert(
          CoursesCompanion.insert(
            id: const Value(1),
            uuid: 'crs-1',
            instituteId: 1,
            name: 'دورة 1447',
            startsOn: DateTime(2026, 9, 1),
            isCurrent: const Value(true),
          ),
        );
    await db.into(db.shifts).insert(
          ShiftsCompanion.insert(
            id: const Value(1),
            uuid: 'shf-1',
            courseId: 1,
            name: 'الدوام الصباحي',
            startsAt: '08:00:00',
            endsAt: '10:00:00',
          ),
        );
    await db.into(db.shiftDays).insert(
          ShiftDaysCompanion.insert(uuid: 'sd-1', shiftId: 1, weekday: 1),
        );
    await db.into(db.circles).insert(
          CirclesCompanion.insert(
            id: const Value(1),
            uuid: 'crc-1',
            instituteId: 1,
            name: 'حلقة الفرقان',
          ),
        );
    await db.into(db.courseCircles).insert(
          CourseCirclesCompanion.insert(
            id: const Value(1),
            uuid: 'cc-1',
            courseId: 1,
            circleId: 1,
            shiftId: 1,
          ),
        );
    await db.into(db.students).insert(
          StudentsCompanion.insert(
            id: const Value(1),
            uuid: 'stu-1',
            instituteId: 1,
            firstName: 'علي',
            fatherName: 'حسن',
            familyName: 'الشامي',
            registrationNo: const Value('S-101'),
          ),
        );
    await db.into(db.enrollments).insert(
          EnrollmentsCompanion.insert(
            id: const Value(1),
            uuid: 'enr-1',
            courseCircleId: 1,
            studentId: 1,
            enrolledOn: Value(DateTime(2026, 9, 1)),
          ),
        );
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        dependencies: dependencies,
        child: MousqeApp(
          // ثيمُ المكتب لا ثيمُ الهاتف — درسُ [CHECKPOINT-PHASE-6.4.MD §7].
          theme: MousqeTheme.light(density: NzDensity.desktop),
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  /// تفكيكُ الشجرة ثم تمريرُ الزمن — تدفّقاتُ drift تُبقي مؤقّتَ إبقاءٍ بعد
  /// انصراف آخر مستمع، وإطارُ الاختبار يفحصها قبل `tearDown`.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 15));
  }

  group('the student roster', () {
    testWidgets('shows each student current circle and the register button',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await pump(tester, const StudentsScreen());
      await tester.pump();

      expect(find.text('علي حسن الشامي'), findsOneWidget);
      expect(find.text('S-101'), findsOneWidget);
      expect(find.text('حلقة الفرقان'), findsOneWidget);
      expect(find.text('تسجيل طالب'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('an account that only reads gets no register button',
        (tester) async {
      // الأستاذُ يملك `students.view` ولا يملك `students.manage`.
      await boot(SeededRoles.teacher);
      await seed();
      await pump(tester, const StudentsScreen());
      await tester.pump();

      expect(find.text('علي حسن الشامي'), findsOneWidget);
      // ولا زرَّ معطَّلاً: بابٌ مقفلٌ ظاهر يجعل نصفَ البرنامج حائطاً.
      expect(find.text('تسجيل طالب'), findsNothing);
      expect(find.byTooltip('نقل إلى حلقة أخرى'), findsNothing);

      await settle(tester);
    });
  });

  group('the registration form', () {
    /// علي ابنُ «حسن الشامي» و«مريم العلي» — كما يصلان في `sync/pull`.
    Future<void> seedParents() async {
      for (final (id, name, relation) in [
        (1, 'حسن الشامي', 'father'),
        (2, 'مريم العلي', 'mother'),
      ]) {
        await db.into(db.guardians).insert(
              GuardiansCompanion.insert(
                id: Value(id),
                uuid: 'grd-$id',
                instituteId: 1,
                fullName: name,
              ),
            );
        await db.into(db.guardianStudentTable).insert(
              GuardianStudentTableCompanion.insert(
                uuid: 'gs-$id',
                guardianId: id,
                studentId: 1,
                relation: Value(relation),
              ),
            );
      }
    }

    /// الاستمارةُ مفتوحةً فوق شاشةٍ أخرى، فيعود منها الحفظُ كما في التطبيق.
    Future<void> openForm(WidgetTester tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const StudentFormScreen(),
              ),
            ),
            child: const Text('افتح'),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String label, String text) =>
        tester.enterText(find.widgetWithText(TextFormField, label), text);

    testWidgets('the father full name follows the personal data, read-only',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await openForm(tester);

      await type(tester, 'اسم الأب *', 'حسان');
      await type(tester, 'اسم العائلة *', 'الأحمد');
      await tester.pump();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'اسم الأب الكامل'),
          matching: find.byType(TextField),
        ),
      );

      expect(field.controller!.text, 'حسان الأحمد');
      expect(field.readOnly, isTrue);
      expect(find.text('اسم الأم الكامل'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('a confirmed brother is linked to the registered parents',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await seedParents();
      await openForm(tester);

      await type(tester, 'اسم الطالب *', 'عمر');
      await type(tester, 'اسم الأب *', 'حسن');
      await type(tester, 'اسم العائلة *', 'الشامي');
      await type(tester, 'اسم الأم الكامل', 'مريم العلي');

      await tester.tap(find.text('حفظ'));
      // مؤشّرُ الحفظ يدور ما دام السؤال مفتوحاً، فلا يستقرّ الإطار.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('هل الطالب عمر حسن الشامي هو أخ الطالب علي حسن الشامي؟'),
        findsOneWidget,
      );

      await tester.tap(find.text('نعم، أخوان'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final operation = await db.select(db.pendingOperations).getSingle();
      final payload = jsonDecode(operation.payload) as Map<String, dynamic>;

      expect(
        payload['sibling_guardian_uuids'],
        {'father': 'grd-1', 'mother': 'grd-2'},
      );

      await settle(tester);
    });

    testWidgets('a declined brother is saved with parents of its own',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await seedParents();
      await openForm(tester);

      await type(tester, 'اسم الطالب *', 'عمر');
      await type(tester, 'اسم الأب *', 'حسن');
      await type(tester, 'اسم العائلة *', 'الشامي');
      await type(tester, 'اسم الأم الكامل', 'مريم العلي');

      await tester.tap(find.text('حفظ'));
      // مؤشّرُ الحفظ يدور ما دام السؤال مفتوحاً، فلا يستقرّ الإطار.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('لا، ليسا أخوين'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final operation = await db.select(db.pendingOperations).getSingle();
      final payload = jsonDecode(operation.payload) as Map<String, dynamic>;

      expect(payload.containsKey('sibling_guardian_uuids'), isFalse);
      expect(
        (payload['guardians'] as Map)['father']['full_name'],
        'حسن الشامي',
      );

      await settle(tester);
    });
  });

  group('absence excuses', () {
    Future<void> seedExcuse() async {
      await db.into(db.absenceExcusesTable).insert(
            AbsenceExcusesTableCompanion.insert(
              uuid: 'exc-1',
              studentId: 1,
              fromDate: DateTime(2026, 9, 20),
              toDate: DateTime(2026, 9, 22),
              reason: 'سفر مع العائلة',
            ),
          );
    }

    testWidgets('a reviewer gets accept and reject on a pending excuse',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await seedExcuse();
      await pump(tester, const ExcusesScreen());
      await tester.pump();

      expect(find.text('علي حسن الشامي'), findsOneWidget);
      expect(find.text('سفر مع العائلة'), findsOneWidget);
      expect(find.text('قبول'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('a decided excuse is not decided twice', (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await db.into(db.absenceExcusesTable).insert(
            AbsenceExcusesTableCompanion.insert(
              uuid: 'exc-2',
              studentId: 1,
              fromDate: DateTime(2026, 9, 1),
              toDate: DateTime(2026, 9, 2),
              reason: 'مرض',
              status: const Value('approved'),
            ),
          );

      await pump(tester, const ExcusesScreen());
      await tester.pump();

      // «المعلَّقة» هو الافتراضي، فالمبتوتُ فيه لا يظهر أصلاً.
      expect(find.text('لا إذنَ ينتظر المراجعة.'), findsOneWidget);

      await tester.tap(find.text('الكل'));
      await tester.pump();

      expect(find.text('مقبول'), findsOneWidget);
      expect(find.text('قبول'), findsNothing);

      await settle(tester);
    });
  });

  group('the course catalogue', () {
    testWidgets('tabs follow the permissions that open them', (tester) async {
      await boot(SeededRoles.admin);
      await seed();
      await pump(tester, const CatalogScreen());
      await tester.pump();

      expect(find.text('الدورات'), findsOneWidget);
      expect(find.text('الدوامات'), findsOneWidget);
      expect(find.text('الحلقات'), findsOneWidget);
      expect(find.text('دورة 1447'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('a supervisor who only reads the catalogue reaches no tab',
        (tester) async {
      // المشرفُ يرى الدوراتِ والحلقات ولا **يديرها** — `*.manage` ليست له.
      await boot(SeededRoles.supervisor);
      await seed();
      await pump(tester, const CatalogScreen());
      await tester.pump();

      expect(find.text('لا تملك صلاحيةَ تهيئةِ بنية الدورة.'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('a shift reads its weekdays, and a circle says it is idle',
        (tester) async {
      await boot(SeededRoles.admin);
      await seed();
      await pump(tester, const CatalogScreen());
      await tester.pump();

      await tester.tap(find.text('الدوامات'));
      await tester.pumpAndSettle();

      expect(find.textContaining('الاثنين'), findsOneWidget);

      await tester.tap(find.text('الحلقات'));
      await tester.pumpAndSettle();

      // الحلقةُ مشغَّلةٌ في هذا المعهد، فتُقال حالتُها لا تُترك للحدس.
      expect(find.textContaining('تعمل في'), findsOneWidget);

      await settle(tester);
    });
  });

  group('curricula', () {
    testWidgets('the fixed quran gets no add or delete, but a global badge',
        (tester) async {
      await boot(SeededRoles.admin);
      await seed();

      await db.into(db.curricula).insert(CurriculaCompanion.insert(
            id: const Value(1),
            uuid: 'cur-quran',
            name: 'القرآن الكريم',
            slug: 'quran',
            type: const Value('quran'),
          ));
      await db.into(db.curriculumItems).insert(CurriculumItemsCompanion.insert(
            uuid: 'itm-juz-30',
            curriculumId: 1,
            name: 'جزء عمّ',
            code: 'juz-30',
          ));

      await pump(tester, const CurriculaScreen());
      await tester.pump();

      expect(find.text('القرآن الكريم'), findsOneWidget);
      expect(find.text('عامّ'), findsOneWidget);
      // أجزاءُ القرآن ثابتة، والمنهجُ العامّ لا يُحرَّر وعاؤه — فلا زرَّ لأيّهما.
      expect(find.byTooltip('بند جديد'), findsNothing);
      expect(find.byTooltip('تحرير المنهج'), findsNothing);

      await settle(tester);
    });

    testWidgets('an institute curriculum gets both, and its item count shows',
        (tester) async {
      await boot(SeededRoles.admin);
      await seed();

      await db.into(db.curricula).insert(CurriculaCompanion.insert(
            id: const Value(2),
            uuid: 'cur-mutun',
            name: 'المتون',
            slug: 'mutun',
            type: const Value('mutun'),
            instituteId: const Value(1),
          ));
      await db.into(db.curriculumItems).insert(CurriculumItemsCompanion.insert(
            uuid: 'itm-bayquniyyah',
            curriculumId: 2,
            name: 'البيقونية',
            code: 'bayquniyyah',
            meta: const Value('{"abyat":34}'),
          ));

      await pump(tester, const CurriculaScreen());
      await tester.pump();

      expect(find.byTooltip('بند جديد'), findsOneWidget);
      expect(find.byTooltip('تحرير المنهج'), findsOneWidget);

      await tester.tap(find.text('المتون'));
      await tester.pumpAndSettle();

      expect(find.textContaining('عدد الأبيات: 34'), findsOneWidget);

      await settle(tester);
    });
  });
}
