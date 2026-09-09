import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_teacher/src/di/app_scope.dart';
import 'package:mousqe_teacher/src/screens/attendance_screen.dart';
import 'package:mousqe_teacher/src/screens/circles_screen.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:retrofit/retrofit.dart';

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

/// ما يبقى خاصّاً بتطبيق الأستاذ بعد أن رُفع مستودعُه إلى `mousqe_core` (م.6.4).
///
/// الاستعلاماتُ والكتابةُ تُختبَر هناك مرّةً للسطحين؛ وما يُختبَر هنا **الفرقان
/// اللذان لا يظهران إلا في شاشته**:
///
/// 1. كشفُه حلقاتُه هو — يمرّر `teacher_uuid` من اللقطة، فلا يرى حلقةَ زميله وهي
///    في مخزنه (السحبُ معهدٌ كامل).
/// 2. جلسةٌ أُكملت لا يحرّرها — **لأن لقطته بلا `attendance.amend`** لا لأن
///    الشيفرة تمنعه. وهو الفرقُ الذي صار معاملاً في م.6.4 بدل أن يكون مفروضاً.
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

  Map<String, dynamic> bootstrapBody() => {
    'user': {
      'name': 'أحمد بن سعيد',
      'roles': ['teacher'],
      // صلاحياتُ الأستاذ كما تبذرها `RolesAndPermissionsSeeder` — وليس فيها
      // `attendance.amend` ولا `attendance.lock`.
      'permissions': [
        'circles.view',
        'students.view',
        'attendance.view',
        'attendance.take',
        'sync.pull',
        'sync.push',
      ],
      'teacher_uuid': 'tch-me',
    },
    'institute': {
      'uuid': 'ins-1',
      'name': 'معهد النور',
      'logo_path': null,
      'theme': {
        'primary': '#0F5132',
        'secondary': '#C9A227',
        'surface': '#F7F3EA',
      },
      'attendance': {'late_grace_minutes': 5},
    },
    'course': {'uuid': 'crs-1', 'name': 'دورة 1447'},
    'circles': <Map<String, dynamic>>[],
  };

  Future<void> boot() async {
    final tokens = _MemoryTokenStore();
    final engine = SyncEngine(
      db: db,
      apiClient: api,
      app: 'teacher',
      deviceUuid: 'device-1',
    );
    final session = SessionController(
      db: db,
      apiClient: api,
      tokenStore: tokens,
      deviceUuid: 'device-1',
      app: 'teacher',
      appLabel: 'تطبيق الأستاذ',
    );
    final repository = CircleRepository(db: db, syncEngine: engine);

    when(
      () => api.bootstrap(),
    ).thenAnswer((_) async => _response(bootstrapBody()));

    dependencies = AppDependencies(
      db: db,
      tokenStore: tokens,
      apiClient: api,
      syncEngine: engine,
      repository: repository,
      session: session,
      sync: SyncController(engine: engine, session: session),
    );

    await session.restore();
  }

  /// حلقتان في نفس المعهد: واحدةٌ لأستاذنا وأخرى لزميله — كلتاهما في مخزنه.
  Future<CircleView> seed({String? sessionStatus}) async {
    await db
        .into(db.institutes)
        .insert(
          InstitutesCompanion.insert(
            id: const Value(1),
            uuid: 'ins-1',
            name: 'معهد النور',
          ),
        );
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            id: const Value(1),
            uuid: 'crs-1',
            instituteId: 1,
            name: 'دورة 1447',
            startsOn: DateTime(2026, 9, 1),
            isCurrent: const Value(true),
          ),
        );
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            id: const Value(1),
            uuid: 'shf-1',
            courseId: 1,
            name: 'الدوام الصباحي',
            startsAt: '08:00:00',
            endsAt: '10:00:00',
          ),
        );

    for (final (id, name, teacherId) in [
      (1, 'حلقة الفرقان', 1),
      (2, 'حلقة النهار', 2),
    ]) {
      await db
          .into(db.circles)
          .insert(
            CirclesCompanion.insert(
              id: Value(id),
              uuid: 'crc-$id',
              instituteId: 1,
              name: name,
            ),
          );
      await db
          .into(db.courseCircles)
          .insert(
            CourseCirclesCompanion.insert(
              id: Value(id),
              uuid: 'cc-$id',
              courseId: 1,
              circleId: id,
              shiftId: 1,
            ),
          );
      await db
          .into(db.teachers)
          .insert(
            TeachersCompanion.insert(
              id: Value(teacherId),
              uuid: teacherId == 1 ? 'tch-me' : 'tch-other',
              instituteId: 1,
              displayName: teacherId == 1 ? 'أحمد بن سعيد' : 'خالد بن عمر',
            ),
          );
      await db
          .into(db.courseCircleTeachers)
          .insert(
            CourseCircleTeachersCompanion.insert(
              id: Value(id),
              uuid: 'cct-$id',
              courseCircleId: id,
              teacherId: teacherId,
            ),
          );
    }

    await db
        .into(db.students)
        .insert(
          StudentsCompanion.insert(
            id: const Value(1),
            uuid: 'stu-1',
            instituteId: 1,
            firstName: 'علي',
            fatherName: 'حسن',
            familyName: 'الشامي',
          ),
        );
    await db
        .into(db.enrollments)
        .insert(
          EnrollmentsCompanion.insert(
            id: const Value(1),
            uuid: 'enr-1',
            courseCircleId: 1,
            studentId: 1,
            enrolledOn: Value(DateTime(2026, 9, 1)),
          ),
        );

    if (sessionStatus != null) {
      await db
          .into(db.attendanceSessions)
          .insert(
            AttendanceSessionsCompanion.insert(
              id: const Value(1),
              uuid: 'ses-1',
              courseCircleId: 1,
              sessionDate: day,
              status: Value(sessionStatus),
            ),
          );
    }

    return (await dependencies.repository.loadCircles('tch-me')).single;
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      AppScope(
        dependencies: dependencies,
        child: MousqeApp(theme: MousqeTheme.fallback(), home: home),
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

  testWidgets('«حلقاتي» is the teacher\'s own, not the institute\'s',
      (tester) async {
    await boot();
    await seed();
    await pump(tester, const CirclesScreen());
    await tester.pump();

    expect(find.text('حلقة الفرقان'), findsOneWidget);
    // حلقةُ الزميل في مخزنه — السحبُ معهدٌ كامل — ولا تظهر في كشفه.
    expect(find.text('حلقة النهار'), findsNothing);

    await settle(tester);
  });

  testWidgets('a completed session is frozen because the snapshot lacks amend',
      (tester) async {
    await boot();
    final circle = await seed(sessionStatus: 'completed');
    await pump(tester, AttendanceScreen(circle: circle, date: day));

    expect(find.text('علي حسن الشامي'), findsOneWidget);
    // لا زرَّ حفظٍ ولا إقفال: الجلسةُ مغلقةٌ في وجه من لا يملك `attendance.amend`.
    expect(find.text('حفظ التفقّد'), findsNothing);
    expect(find.text('إقفال'), findsNothing);

    await settle(tester);
  });

  testWidgets('a draft session is his to write', (tester) async {
    await boot();
    final circle = await seed(sessionStatus: 'draft');
    await pump(tester, AttendanceScreen(circle: circle, date: day));

    expect(find.text('حفظ التفقّد'), findsOneWidget);
    expect(find.text('إقفال'), findsOneWidget);

    await settle(tester);
  });
}
