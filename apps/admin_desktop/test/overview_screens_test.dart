import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_admin_desktop/src/di/app_scope.dart';
import 'package:mousqe_admin_desktop/src/reports/report_documents.dart';
import 'package:mousqe_admin_desktop/src/reports/report_fonts.dart';
import 'package:mousqe_admin_desktop/src/screens/backup_screen.dart';
import 'package:mousqe_admin_desktop/src/screens/conflicts_screen.dart';
import 'package:mousqe_admin_desktop/src/screens/dashboard_screen.dart';
import 'package:mousqe_admin_desktop/src/screens/reports_screen.dart';
import 'package:mousqe_admin_desktop/src/state/institute_switcher.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
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

/// مجلّدُ مستنداتٍ مؤقّت — تنفيذُ `path_provider` على ويندوز دارتٌ صرف يقرأ
/// مجلّداتِ النظام، فيُبدَّل الكائنُ لا تُقلَّد قناة.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

HttpResponse<dynamic> _response(Object? data) =>
    HttpResponse(data, Response(requestOptions: RequestOptions(), data: data));

/// الاطّلاعُ وصحّةُ النظام — ✅ م.6.6، الأبوابُ الأربعة الأخيرة.
///
/// وما يُقاس هنا **ليس تجميعَ الأرقام** — ذاك في `stats_repository_test` — بل
/// أربعةُ أشياءَ لا يقولها إلا رسمُ الشاشة:
///
/// 1. أن الداشبورد يفرّق بين «لم يُقَس» و«صفر» في الورقة نفسِها.
/// 2. أن التقرير يخرج **PDF عربياً حقيقياً** بخطٍّ فيه حروفُه.
/// 3. أن التعارضات تعرض **الخلافَ وحده** وتميّز الانقطاع من الرفض.
/// 4. أن النسخة الاحتياطية تقول لصاحبها **ما الذي في خطر**.
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

  Future<void> boot(
    List<String> permissions, {
    Map<String, dynamic>? points,
  }) async {
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
      (_) async => _response(
        bootstrapBody(permissions: permissions, points: points),
      ),
    );

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
      stats: StatsRepository(db: db),
      conflicts: ConflictRepository(apiClient: api),
    );

    await session.restore();
  }

  /// معهدٌ بدورةٍ جارية وحلقةٍ وطالبين — كما يصل في `sync/pull`.
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
        uuid: 'cct-1',
        courseCircleId: 1,
        teacherId: 1,
      ),
    );

    for (final (id, first) in [(1, 'علي'), (2, 'بدر')]) {
      await db.into(db.students).insert(
        StudentsCompanion.insert(
          id: Value(id),
          uuid: 'stu-$id',
          instituteId: 1,
          firstName: first,
          fatherName: 'حسن',
          familyName: 'الشامي',
        ),
      );
      await db.into(db.enrollments).insert(
        EnrollmentsCompanion.insert(
          uuid: 'enr-$id',
          courseCircleId: 1,
          studentId: id,
          enrolledOn: Value(DateTime(2026, 9, 1)),
        ),
      );
    }
  }

  /// جلسةُ اليوم: حاضرٌ وغائب ⇒ ٥٠٪.
  Future<void> seedToday() async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    await db.into(db.attendanceSessions).insert(
      AttendanceSessionsCompanion.insert(
        id: const Value(1),
        uuid: 'ses-1',
        courseCircleId: 1,
        sessionDate: day,
        status: const Value('completed'),
      ),
    );

    for (final (id, status) in [(1, 'present'), (2, 'absent')]) {
      await db.into(db.attendances).insert(
        AttendancesCompanion.insert(
          uuid: 'att-$id',
          attendanceSessionId: 1,
          studentId: id,
          status: Value(status),
          recordedAt: day.add(const Duration(hours: 8)),
        ),
      );
    }
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
          theme: MousqeTheme.forDesktop(MousqeTheme.fallback()),
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  /// تفكيكُ الشجرة ثم تمريرُ الزمن — تدفّقاتُ drift تُبقي مؤقّتَ إبقاء.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 15));
  }

  group('the dashboard', () {
    testWidgets('counts the store and rates today from what was recorded',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await seedToday();
      await pump(tester, const DashboardScreen());
      await tester.pump();

      expect(find.text('طالبٌ في المعهد'), findsOneWidget);
      expect(find.text('مسجَّلٌ في الدورة الجارية'), findsOneWidget);
      expect(find.text('اليوم: 50.0٪'), findsOneWidget);
      expect(find.text('حلقة الفرقان'), findsOneWidget);
      expect(find.text('أحمد بن سعيد'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('a circle nobody took attendance for reads "unmeasured"',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await pump(tester, const DashboardScreen());
      await tester.pump();

      // 🔑 لا صفرَ ولا ١٠٠٪: الحلقةُ لم تُقَس، والترتيبُ لا يشملها. ولو رُسمت
      // صفراً لَبدت أسوأَ من حلقةٍ غاب طلابُها كلُّهم.
      expect(find.text('اليوم: لم يُسجَّل تفقّدٌ بعد'), findsOneWidget);
      expect(find.text('لم تُقَس'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('an institute with no running course is sent to the courses door',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await pump(tester, const DashboardScreen());
      await tester.pump();

      expect(find.textContaining('لا دورةَ جاريةٌ'), findsOneWidget);

      await settle(tester);
    });
  });

  group('the printed report', () {
    testWidgets('builds real Arabic PDF bytes from the store, offline',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await seedToday();

      // 🔑 خطوطُ `pdf` المدمجة بلا حرفٍ عربيٍّ واحد، فتقريرٌ يُبنى بها يخرج
      // مربّعاتٍ فارغة **بلا خطأ يُرمى**. والخطُّ يُقرأ من أصول `mousqe_ui`.
      final fonts = await ReportFonts.load();

      final report = await dependencies.stats.loadDailyReport(
        courseCircleId: 1,
        date: DateTime.now(),
      );

      final document = await ReportDocuments.daily(
        report: report!,
        fonts: fonts,
        instituteName: 'معهد النور',
      );

      final bytes = await document.save();

      expect(bytes.length, greaterThan(1000));
      // ولا طلبَ شبكةٍ واحد في الطريق: التقريرُ يخرج والشبكةُ مقطوعة.
      verifyNever(() => api.syncPull(any(), any(), any()));
    });

    testWidgets('points columns follow the institute values from the snapshot',
        (tester) async {
      await boot(
        SeededRoles.supervisor,
        points: const {
          'quran_per_15_lines': 10,
          'hadith_per_item': 5,
          'mutun_per_bayt': 1,
          'attendance': {'present': 7, 'late': 3, 'excused': 0, 'absent': 0},
        },
      );
      await seed();
      await seedToday();

      final settings = dependencies.session.snapshot!.institute.points;

      expect(settings.presentPoints, 7);

      final report = await dependencies.stats.loadPointsReport(
        courseCircleId: 1,
        from: DateTime.now(),
        to: DateTime.now(),
        points: settings,
      );

      // حاضرٌ واحد بسبعِ نقاطٍ — لا نقطتين كما تقول افتراضياتُ الحزمة.
      expect(report!.rows.first.attendance, 7);
    });

    testWidgets('with no running circle there is nothing to print, and it says so',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await pump(tester, const ReportsScreen());
      await tester.pump();

      expect(find.textContaining('لا حلقةَ مشغَّلةٌ'), findsOneWidget);

      await settle(tester);
    });
  });

  group('the conflicts door', () {
    Map<String, dynamic> conflictBody({String? resolvedAt}) => {
      'data': [
        {
          'uuid': 'cnf-1',
          'table_name': 'attendances',
          'row_uuid': 'att-9',
          'server_payload': {
            'status': 'excused',
            'student_id': 1,
            'note': null,
          },
          'client_payload': {'status': 'absent', 'student_id': 1, 'note': null},
          'resolution': 'server_wins',
          'device_uuid': 'device-2',
          'reviewed_by': null,
          'resolved_at': resolvedAt,
          'created_at': '2026-09-15T17:40:00+00:00',
        },
      ],
    };

    testWidgets('shows only the keys that actually differ', (tester) async {
      await boot(SeededRoles.supervisor);

      when(() => api.syncConflicts('pending'))
          .thenAnswer((_) async => _response(conflictBody()));

      await pump(tester, const ConflictsScreen());
      await tester.pump();

      expect(find.text('attendances'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      // 🔑 `student_id` و`note` متطابقان فلا يُعرضان: من يقرّر على عشرين مفتاحاً
      // متطابقاً يدفن الخلافَ الوحيد الذي وقع الحكمُ عليه.
      expect(find.text('student_id'), findsNothing);
      expect(find.text('note'), findsNothing);

      expect(find.text('اعتمِد قيمة الجهاز'), findsOneWidget);
      expect(find.text('أبقِ قيمة الخادم'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('an already reviewed conflict is not judged twice',
        (tester) async {
      await boot(SeededRoles.supervisor);

      when(() => api.syncConflicts('pending')).thenAnswer(
        (_) async =>
            _response(conflictBody(resolvedAt: '2026-09-15T18:00:00+00:00')),
      );

      await pump(tester, const ConflictsScreen());
      await tester.pump();

      expect(find.text('status'), findsOneWidget);
      expect(find.text('اعتمِد قيمة الجهاز'), findsNothing);

      await settle(tester);
    });

    testWidgets('an account without the permission sees them and judges nothing',
        (tester) async {
      // الأستاذ يملك `sync.pull` ولا يملك `conflicts.review`.
      await boot(SeededRoles.teacher);

      when(() => api.syncConflicts('pending'))
          .thenAnswer((_) async => _response(conflictBody()));

      await pump(tester, const ConflictsScreen());
      await tester.pump();

      expect(find.text('اعتمِد قيمة الجهاز'), findsNothing);

      await settle(tester);
    });

    testWidgets('losing the network is told apart from the server refusing',
        (tester) async {
      await boot(SeededRoles.supervisor);

      when(() => api.syncConflicts('pending')).thenThrow(
        DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'no route to host',
        ),
      );

      await pump(tester, const ConflictsScreen());
      await tester.pump();

      // الجدولُ لا يُزامَن، فلا مخزنَ يُقرأ منه — والرسالةُ تقول ذلك بدل
      // «تعذّرت القراءة» التي لا تخبر صاحبَها بشيء.
      expect(find.textContaining('أعِد المحاولة حين تعود الشبكة'), findsOneWidget);

      await settle(tester);
    });
  });

  group('the local backup', () {
    late Directory documents;

    setUp(() {
      documents = Directory.systemTemp.createTempSync('mousqe-docs');
      PathProviderPlatform.instance = _FakePathProvider(documents.path);
    });

    tearDown(() => documents.deleteSync(recursive: true));

    testWidgets('says what is at risk before it copies anything',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await pump(tester, const BackupScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('الطابورُ فارغ — كلُّ ما على هذا الجهاز وصل الخادم.'),
        findsOneWidget,
      );

      // 🔑 وعمليةٌ في الطابور تقلب الرسالة: هي **وحدها** ما لا يوجد على الخادم،
      // وبقيّةُ المخزن تعود بأوّل مزامنة.
      await dependencies.syncEngine.enqueue('attendance.take', const {
        'session_uuid': 'ses-1',
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('لم تصل الخادمَ بعد'), findsOneWidget);

      await settle(tester);
    });

    testWidgets('writing a snapshot lands a file that can be reopened',
        (tester) async {
      await boot(SeededRoles.supervisor);
      await seed();
      await pump(tester, const BackupScreen());
      await tester.pumpAndSettle();

      // 🔑 `runAsync`: كتابةُ النسخة إدخالٌ وإخراجٌ حقيقيّ على القرص، وزمنُ
      // `testWidgets` مُصطنَع — فمستقبَلُ `dart:io` لا يكتمل داخله أبداً. ولا
      // `pumpAndSettle` بعده أيضاً: الزرُّ يعرض دوّارةً لا تستقرّ.
      await tester.runAsync(() async {
        await tester.tap(find.text('احفظ نسخةً الآن'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });

      await tester.pump();

      final backups = await DatabaseBackup.list(
        Directory('${documents.path}/mousqe-backups'),
      );

      // أن اللقطةَ تُفتح وحدها يقيسه `stats_repository_test`؛ وما تضيفه الشاشةُ
      // هو **أين تقع**: في «المستندات» لا في مجلّد بيانات التطبيق المخفيّ الذي
      // أُخرج إليه مخزنُ drift في م.6.3 — فنسخةٌ لا يجدها صاحبُها بلا غاية.
      expect(backups, hasLength(1));
      expect(backups.single.lengthSync(), greaterThan(0));
      expect(find.textContaining('mousqe-backups'), findsOneWidget);

      await settle(tester);
    });
  });
}
