import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_admin_desktop/src/di/app_scope.dart';
import 'package:mousqe_admin_desktop/src/screens/attendance_screen.dart';
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

/// شاشةُ التفقّد تُبنى على ما يملكه فاتحُها — ✅ م.6.4.
///
/// وهو نظيرُ اختبار القائمة الجانبية في م.6.3 داخلَ شاشة: ما لا يملكه المستخدم
/// لا يظهر أصلاً، لا معطَّلاً ولا برسالةِ رفضٍ عند الضغط. والفرقُ الذي يقيسه هذا
/// الملف بين **ثلاث لقطات** لنفس الجلسة ونفس الشيفرة.
void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late AppDependencies dependencies;

  final day = DateTime(2026, 9, 15);

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

    when(
      () => api.bootstrap(),
    ).thenAnswer((_) async => _response(bootstrapBody(permissions: permissions)));

    dependencies = AppDependencies(
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
    );

    await session.restore();
  }

  /// حلقةٌ بأستاذٍ وطالبٍ واحد، وجلسةُ يومٍ بحالةٍ مُعطاة — مزروعةٌ في drift
  /// مباشرةً كما تصل في `sync/pull`.
  Future<CircleView> seed({String? sessionStatus}) async {
    await db.into(db.institutes).insert(
          InstitutesCompanion.insert(id: const Value(1), uuid: 'ins-1', name: 'معهد النور'),
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
    await db.into(db.circles).insert(
          CirclesCompanion.insert(
            id: const Value(1),
            uuid: 'crc-1',
            instituteId: 1,
            name: 'حلقة الفرقان',
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
    await db.into(db.courseCircles).insert(
          CourseCirclesCompanion.insert(
            id: const Value(1),
            uuid: 'cc-1',
            courseId: 1,
            circleId: 1,
            shiftId: 1,
          ),
        );
    await db.into(db.teachers).insert(
          TeachersCompanion.insert(
            id: const Value(1),
            uuid: 'tch-1',
            instituteId: 1,
            displayName: 'أحمد بن سعيد',
          ),
        );
    await db.into(db.courseCircleTeachers).insert(
          CourseCircleTeachersCompanion.insert(
            id: const Value(1),
            uuid: 'cct-1',
            courseCircleId: 1,
            teacherId: 1,
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

    if (sessionStatus != null) {
      await db.into(db.attendanceSessions).insert(
            AttendanceSessionsCompanion.insert(
              id: const Value(1),
              uuid: 'ses-1',
              courseCircleId: 1,
              sessionDate: day,
              status: Value(sessionStatus),
            ),
          );
    }

    return (await dependencies.circles.loadCircles()).single;
  }

  Future<void> pump(WidgetTester tester, CircleView circle) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        dependencies: dependencies,
        child: MousqeApp(
          // ثيمُ المكتب لا ثيمُ الهاتف: أزرارُ الأخير `Size.fromHeight` — عريضةٌ
          // بعرض الشاشة، فتنفجر داخل صفٍّ فيه أكثرُ من زرّ. وهو ما يبنيه
          // `app.dart` فعلاً، فاختبارٌ بغيره يقيس شاشةً لا وجود لها.
          theme: MousqeTheme.forDesktop(MousqeTheme.fallback()),
          home: AttendanceScreen(circle: circle, date: day),
        ),
      ),
    );
    await tester.pump();
  }

  /// تفكيكُ الشجرة داخل الاختبار ثم تمريرُ الزمن — تدفّقاتُ drift تُبقي مؤقّتَ
  /// إبقاءٍ بعد انصراف آخر مستمع، وإطارُ الاختبار يفحصها قبل `tearDown`.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 15));
  }

  testWidgets('the supervisor gets the lock and the teacher roll',
      (tester) async {
    await boot(SeededRoles.supervisor);
    final circle = await seed();
    await pump(tester, circle);

    expect(find.text('علي حسن الشامي'), findsOneWidget);
    expect(find.text('قفل نهائي'), findsOneWidget);
    expect(find.text('تفقّد الأساتذة'), findsOneWidget);
    expect(find.text('أحمد بن سعيد'), findsOneWidget);

    await settle(tester);
  });

  testWidgets('an account without the two permissions sees neither door',
      (tester) async {
    // حسابٌ يتفقّد ولا يقفل ولا يرى الأساتذة — نظيرُ الأستاذ في الصلاحيات.
    await boot(SeededRoles.teacher);
    final circle = await seed();
    await pump(tester, circle);

    expect(find.text('علي حسن الشامي'), findsOneWidget);
    // لا زرٌّ معطَّل ولا رسالةُ «لا تملك الصلاحية» — لا يظهر أصلاً.
    expect(find.text('قفل نهائي'), findsNothing);
    expect(find.text('تفقّد الأساتذة'), findsNothing);

    await settle(tester);
  });

  testWidgets('a completed session tells the amender that this is a correction',
      (tester) async {
    await boot(SeededRoles.supervisor);
    final circle = await seed(sessionStatus: 'completed');
    await pump(tester, circle);

    // بانرٌ لا سماحٌ صامت: من يعدّل جلسةً أُكملت يجب أن يعرف أنه يصحّح رجعياً.
    expect(find.textContaining('تصحيحٌ رجعي'), findsOneWidget);
    expect(find.text('حفظ التصحيح'), findsOneWidget);
    // والمكتملةُ لا تُكمَل مرّتين.
    expect(find.text('إكمال'), findsNothing);

    await settle(tester);
  });

  testWidgets('and tells the one who cannot amend why the roll is frozen',
      (tester) async {
    await boot(SeededRoles.teacher);
    final circle = await seed(sessionStatus: 'completed');
    await pump(tester, circle);

    expect(find.textContaining('تعديلُها يحتاج صلاحية'), findsOneWidget);
    expect(find.text('حفظ التصحيح'), findsNothing);

    await settle(tester);
  });

  testWidgets('a locked session is frozen even for the one who locked it',
      (tester) async {
    await boot(SeededRoles.supervisor);
    final circle = await seed(sessionStatus: 'locked');
    await pump(tester, circle);

    expect(find.textContaining('مقفلة نهائياً'), findsOneWidget);
    expect(find.text('حفظ التصحيح'), findsNothing);
    // ولا تُقفل مرّتين.
    expect(find.text('قفل نهائي'), findsNothing);

    await settle(tester);
  });
}
