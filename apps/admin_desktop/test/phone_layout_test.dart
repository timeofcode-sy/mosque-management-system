import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_admin_desktop/src/app.dart';
import 'package:mousqe_admin_desktop/src/di/app_scope.dart';
import 'package:mousqe_admin_desktop/src/shell/desktop_shell.dart';
import 'package:mousqe_admin_desktop/src/shell/destinations.dart';
import 'package:mousqe_admin_desktop/src/shell/phone_shell.dart';
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

/// خطوطُ الهوية من ملفّاتها — بخطّ الاختبار (مربّعات Ahem) لا يُقاس عرضُ نصٍّ
/// عربيّ على هاتف، ولا تُقرأ لقطة.
Future<void> _loadBrandFonts() async {
  const root = '../../packages/nuzul_ui/fonts';
  const families = {
    'ReemKufi': ['Regular', 'SemiBold', 'Bold'],
    'IBMPlexSansArabic': ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold'],
    'Amiri': ['Regular', 'Bold'],
  };

  for (final MapEntry(key: family, value: weights) in families.entries) {
    final loader = FontLoader('packages/nuzul_ui/$family');

    for (final weight in weights) {
      final bytes = File('$root/$family-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }

    await loader.load();
  }
}

/// نسخةُ الهاتف — ✅ الشريطُ السفلي و«المزيد»، وكلُّ بابٍ يُبنى في 360px بلا فيض.
///
/// والمقاسُ هاتفٌ صغيرٌ حقيقي (360×780): ما يسعه يسعه كلُّ هاتف. والخطوطُ خطوطُ
/// الهوية لا خطُّ الاختبار، فالقياسُ قياسُ ما يراه المشرفُ في يده.
///
/// `ADMIN_SHOTS=<مجلّد>` يحفظ لقطةً لكل باب — للمراجعة بالعين لا للمقارنة.
void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late AppDependencies dependencies;

  final shotsDir = Platform.environment['ADMIN_SHOTS'];
  final shotKey = GlobalKey();

  setUpAll(() async {
    registerFallbackValue(<String, dynamic>{});
    await _loadBrandFonts();

    // معاينةُ التقارير تكلّم وصلةَ `printing` الأصلية — ولا وصلاتِ في
    // الاختبار، فتُجاب بلا شيء: يبقى المؤشّرُ يدور والشاشةُ حولها تُقاس.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.nfet.printing'),
          (call) async => call.method == 'printingInfo'
              ? {
                  'directPrint': false,
                  'dynamicLayout': false,
                  'canPrint': true,
                  'canConvertHtml': false,
                  'canShare': true,
                  'canRaster': false,
                  'canListPrinters': false,
                }
              : null,
        );
    // ونسخُ الطوارئ يسأل عن مجلّد المستندات.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

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
      app: 'admin_mobile',
      deviceUuid: 'device-1',
    );
    final session = SessionController(
      db: db,
      apiClient: api,
      tokenStore: tokens,
      deviceUuid: 'device-1',
      app: 'admin_mobile',
      appLabel: 'إدارة المعهد',
      activeInstitute: ActiveInstitute(),
    );
    final sync = SyncController(engine: engine, session: session);

    when(() => api.bootstrap()).thenAnswer(
      (_) async => _response(bootstrapBody(permissions: permissions)),
    );
    when(() => api.adminRoles()).thenAnswer(
      (_) async => _response({
        'data': [
          {
            'name': 'supervisor',
            'label': 'مشرف',
            'is_global': false,
            'rank': 2,
          },
        ],
      }),
    );
    when(() => api.adminUsers(any(), any(), any())).thenAnswer(
      (_) async => _response({
        'data': [
          for (final (id, name, active) in [
            (1, 'عبد الرحمن بن محمد الخطيب', true),
            (2, 'سعيد بن أحمد', false),
          ])
            {
              'id': id,
              'name': name,
              'username': 'user$id',
              'is_active': active,
              'roles': [
                {
                  'role': 'supervisor',
                  'label': 'مشرف',
                  'institute': 'معهد النور لتحفيظ القرآن الكريم',
                  'is_global': false,
                },
              ],
            },
        ],
      }),
    );
    when(() => api.adminCredentials(any(), any())).thenAnswer(
      (_) async => _response({
        'data': [
          for (var id = 1; id <= 3; id++)
            {
              'id': id,
              'name': 'محمد بن عبد الله الحلبي $id',
              'role': 'student',
              'username': 'S-10$id',
              'password': id == 2 ? null : 'Kx7-pq2$id',
              'is_active': id != 3,
              'detail': 'حلقة الفرقان · الدوام الصباحي',
            },
        ],
      }),
    );
    when(() => api.syncConflicts(any())).thenAnswer(
      (_) async => _response({
        'data': [
          {
            'uuid': 'cf-1',
            'table_name': 'attendances',
            'row_uuid': '9a1f2c4e-3b7d-4c55-9e0a-1f2b3c4d5e6f',
            'server_payload': {'status': 'absent', 'late_minutes': null},
            'client_payload': {'status': 'late', 'late_minutes': 12},
            'device_uuid': 'device-7',
            'created_at': '2026-10-09T08:15:00Z',
          },
        ],
      }),
    );
    when(() => api.institutes()).thenAnswer(
      (_) async => _response({
        'current': 'ins-1',
        'data': [
          {'uuid': 'ins-1', 'name': 'معهد النور', 'is_active': true},
          {
            'uuid': 'ins-2',
            'name': 'معهد الهدى لتحفيظ القرآن',
            'is_active': true,
          },
        ],
      }),
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

  /// معهدٌ عامرٌ بأسماءٍ طويلة: ما يُقاس بعرض الهاتف يُقاس بأسوأ ما يُكتب فيه.
  Future<void> seed() async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

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

    for (final (id, name, starts) in [
      (1, 'الدوام الصباحي', '08:00:00'),
      (2, 'دوام ما بعد العصر', '16:00:00'),
    ]) {
      await db
          .into(db.shifts)
          .insert(
            ShiftsCompanion.insert(
              id: Value(id),
              uuid: 'shf-$id',
              courseId: 1,
              name: name,
              startsAt: starts,
              endsAt: '10:00:00',
            ),
          );

      for (final weekday in [0, 1, 2, 3, 6]) {
        await db
            .into(db.shiftDays)
            .insert(
              ShiftDaysCompanion.insert(
                uuid: 'sd-$id-$weekday',
                shiftId: id,
                weekday: weekday,
              ),
            );
      }
    }

    const circles = [
      'حلقة الفرقان لتحفيظ القرآن الكريم',
      'حلقة الإمام النووي',
      'حلقة أبي بن كعب',
      'حلقة زيد بن ثابت',
    ];

    for (var i = 0; i < circles.length; i++) {
      final id = i + 1;

      await db
          .into(db.circles)
          .insert(
            CirclesCompanion.insert(
              id: Value(id),
              uuid: 'crc-$id',
              instituteId: 1,
              name: circles[i],
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
              shiftId: i.isEven ? 1 : 2,
              room: Value('القاعة الكبرى $id'),
              capacity: const Value(12),
            ),
          );
      await db
          .into(db.teachers)
          .insert(
            TeachersCompanion.insert(
              id: Value(id),
              uuid: 'tch-$id',
              instituteId: 1,
              displayName: 'الشيخ عبد الرحمن بن محمد $id',
            ),
          );
      await db
          .into(db.courseCircleTeachers)
          .insert(
            CourseCircleTeachersCompanion.insert(
              uuid: 'cct-$id',
              courseCircleId: id,
              teacherId: id,
            ),
          );
    }

    const names = [
      ('عبد الرحمن', 'محمد أمين', 'الخطيب الحسيني'),
      ('علي', 'حسن', 'الشامي'),
      ('بدر', 'حسن', 'الشامي'),
      ('عمر', 'خالد', 'الحلبي'),
      ('يوسف', 'إبراهيم', 'العطار'),
      ('محمد نور', 'عبد الكريم', 'الدمشقي'),
      ('أنس', 'سامر', 'القباني'),
      ('حمزة', 'ياسر', 'النجار'),
    ];

    for (var i = 0; i < names.length; i++) {
      final id = i + 1;
      final (first, father, family) = names[i];

      await db
          .into(db.students)
          .insert(
            StudentsCompanion.insert(
              id: Value(id),
              uuid: 'stu-$id',
              instituteId: 1,
              firstName: first,
              fatherName: father,
              familyName: family,
              registrationNo: Value('S-10$id'),
              phone: Value('0944 123 45$id'),
            ),
          );

      // الأخيران بلا حلقة — لبابِ «التسجيل والنقل».
      if (i < names.length - 2) {
        await db
            .into(db.enrollments)
            .insert(
              EnrollmentsCompanion.insert(
                uuid: 'enr-$id',
                courseCircleId: 1,
                studentId: id,
                enrolledOn: Value(DateTime(2026, 9, 1)),
              ),
            );
      }
    }

    // أسبوعان من الجلسات للمنحنى، وجلسةُ اليوم مسوّدة.
    var attendanceId = 0;

    for (var back = 13; back >= 0; back--) {
      final date = day.subtract(Duration(days: back));
      final sessionId = 14 - back;

      if (date.weekday == DateTime.friday) {
        continue;
      }

      await db
          .into(db.attendanceSessions)
          .insert(
            AttendanceSessionsCompanion.insert(
              id: Value(sessionId),
              uuid: 'ses-$sessionId',
              courseCircleId: 1,
              sessionDate: date,
              status: Value(back == 0 ? 'draft' : 'completed'),
            ),
          );

      for (var student = 1; student <= 6; student++) {
        attendanceId++;
        final status = switch ((student + back) % 7) {
          0 => 'absent',
          1 => 'late',
          2 => 'excused',
          _ => 'present',
        };

        await db
            .into(db.attendances)
            .insert(
              AttendancesCompanion.insert(
                uuid: 'att-$attendanceId',
                attendanceSessionId: sessionId,
                studentId: student,
                status: Value(status),
                lateMinutes: Value(status == 'late' ? 7 : null),
                note: Value(student == 1 ? 'حفظ ممتاز اليوم' : null),
                recordedAt: date.add(const Duration(hours: 8)),
              ),
            );
      }
    }

    for (final (id, student, reason) in [
      (1, 2, 'سفرٌ عائليّ إلى حلب لحضور عرس ابن العم'),
      (2, 4, 'مرض'),
    ]) {
      await db
          .into(db.absenceExcusesTable)
          .insert(
            AbsenceExcusesTableCompanion.insert(
              uuid: 'exc-$id',
              studentId: student,
              fromDate: day,
              toDate: day.add(const Duration(days: 2)),
              reason: reason,
            ),
          );
    }

    await db
        .into(db.curricula)
        .insert(
          CurriculaCompanion.insert(
            id: const Value(1),
            uuid: 'cur-1',
            instituteId: const Value(1),
            name: 'متن تحفة الأطفال والغلمان في تجويد القرآن',
            slug: 'tuhfa',
          ),
        );

    for (var i = 1; i <= 3; i++) {
      await db
          .into(db.curriculumItems)
          .insert(
            CurriculumItemsCompanion.insert(
              uuid: 'item-$i',
              curriculumId: 1,
              name: 'باب أحكام النون الساكنة والتنوين $i',
              code: 'T-$i',
              sortOrder: Value(i),
            ),
          );
    }
  }

  Widget app({bool dark = false}) {
    final theme = adaptTheme(
      dark
          ? MousqeTheme.dark(density: NzDensity.touch)
          : MousqeTheme.light(density: NzDensity.touch),
    );

    return RepaintBoundary(
      key: shotKey,
      child: AppScope(
        dependencies: dependencies,
        child: MousqeApp(theme: theme, home: const DesktopShell()),
      ),
    );
  }

  /// إطاراتٌ لا `pumpAndSettle`: مؤشّرُ التحميل يدور بلا نهاية فلا يستقرّ.
  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpPhone(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(dark: dark));
    await idle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (shotsDir == null) {
      return;
    }

    await tester.runAsync(() async {
      final boundary =
          shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);

      Directory(shotsDir).createSync(recursive: true);
      File('$shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 15));
  }

  /// ما في «المزيد» قد يقع تحت الطيّة — يُمرَّر إليه قبل الضغط.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find
          .descendant(
            of: find.byType(MoreScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // «وُجد» لا تعني «ظهر»: القائمةُ تبني ما تحت الطيّة قبل أن يظهر.
    await tester.ensureVisible(finder);
    await idle(tester);
  }

  Finder navItem(String label) =>
      find.descendant(of: find.byType(PhoneNavBar), matching: find.text(label));

  testWidgets('the phone gets a bottom bar of four doors and «المزيد»', (
    tester,
  ) async {
    await boot(SeededRoles.developer);
    await seed();
    await pumpPhone(tester);

    expect(find.byType(PhoneNavBar), findsOneWidget);
    for (final label in [
      'الرئيسية',
      'التفقّد',
      'الطلاب',
      'الحلقات',
      'المزيد',
    ]) {
      expect(navItem(label), findsOneWidget, reason: label);
    }

    // لا قائمةَ جانبية على الهاتف.
    expect(find.byTooltip('طيّ القائمة'), findsNothing);
    await shot(tester, '01-dashboard');

    await tester.tap(navItem('المزيد'));
    await idle(tester);

    // البقيّةُ في «المزيد» بعناوين القائمة الجانبية، والخروجُ آخرُها.
    expect(find.text('أعذار الغياب'), findsOneWidget);
    expect(find.text('معهد النور'), findsWidgets);
    await shot(tester, '02-more');

    await reveal(tester, find.text('تسجيل الخروج'));
    expect(find.text('بيانات المعهد'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
    await shot(tester, '03-more-bottom');

    await settle(tester);
  });

  testWidgets('pending excuses are counted on the tab that holds them', (
    tester,
  ) async {
    await boot(SeededRoles.developer);
    await seed();
    await pumpPhone(tester);

    final bar = find.byType(PhoneNavBar);

    expect(find.descendant(of: bar, matching: find.text('2')), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a door opened from «المزيد» returns to it with back', (
    tester,
  ) async {
    await boot(SeededRoles.developer);
    await seed();
    await pumpPhone(tester);

    await tester.tap(navItem('المزيد'));
    await idle(tester);
    await tester.tap(find.text('أعذار الغياب'));
    await idle(tester);

    expect(find.text('سفرٌ عائليّ إلى حلب لحضور عرس ابن العم'), findsOneWidget);

    // زرُّ الرجوع في أندرويد يغلق البابَ ولا يُخرج من التطبيق.
    await tester.binding.handlePopRoute();
    await idle(tester);

    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('سفرٌ عائليّ إلى حلب لحضور عرس ابن العم'), findsNothing);
    await settle(tester);
  });

  testWidgets('a supervisor gets the doors a supervisor owns', (tester) async {
    await boot(SeededRoles.supervisor);
    await seed();
    await pumpPhone(tester);

    final tabs = splitPhoneTabs(
      visibleSections(snapshotOf(SeededRoles.supervisor)),
    );

    expect(tabs.primary.map((s) => s.id), [
      'dashboard',
      'attendance',
      'students',
      'circles',
    ]);
    expect(tabs.secondary.map((s) => s.id), isNot(contains('users')));
    await settle(tester);
  });

  testWidgets('the attendance sheet, the form and the profile fit the phone', (
    tester,
  ) async {
    await boot(SeededRoles.developer);
    await seed();
    await pumpPhone(tester);

    final errors = <String>[];
    final previous = FlutterError.onError;
    var current = 'shell';
    FlutterError.onError = (details) => errors.add(
      '$current: ${details.exceptionAsString().split('\n').first}',
    );

    try {
      // كشفُ التفقّد: الحالاتُ الأربع بعرض الشاشة تحت كل اسم.
      current = 'attendance-sheet';
      await tester.tap(navItem('التفقّد'));
      await idle(tester);
      await tester.tap(find.text('حلقة الفرقان لتحفيظ القرآن الكريم'));
      await idle(tester);
      expect(find.text('حفظ التفقّد'), findsOneWidget);
      await shot(tester, 'deep-attendance-sheet');

      // استمارةُ التسجيل من الزرّ العائم.
      current = 'student-form';
      await tester.tap(navItem('الطلاب'));
      await idle(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await idle(tester);
      expect(find.text('تسجيل طالب جديد'), findsOneWidget);
      await shot(tester, 'deep-student-form');

      // ضغطُ اللسان الجاري يعيده إلى أوّله.
      await tester.tap(navItem('الطلاب'));
      await idle(tester);
      expect(find.text('تسجيل طالب جديد'), findsNothing);

      current = 'student-profile';
      await tester.tap(find.text('علي حسن الشامي'));
      await idle(tester);
      expect(find.text('نسبة الحضور'), findsOneWidget);
      await shot(tester, 'deep-student-profile');
    } finally {
      FlutterError.onError = previous;
    }

    expect(errors, isEmpty);
    await settle(tester);
  });

  // كلُّ بابٍ في 360px — والفيضُ خطأٌ يُسجَّل باسم بابه.
  for (final dark in [false, true]) {
    testWidgets(
      'every door builds at 360px without overflow (${dark ? 'night' : 'light'})',
      (tester) async {
        await boot(SeededRoles.developer);
        await seed();
        await pumpPhone(tester, dark: dark);

        final errors = <String>[];
        final previous = FlutterError.onError;
        var current = 'shell';
        FlutterError.onError = (details) {
          // معاينةُ PDF تطلب وصلةَ `printing` الأصلية، ولا وصلاتِ في الاختبار.
          if (details.exception is MissingPluginException) {
            return;
          }

          errors.add(
            '$current: ${details.exceptionAsString().split('\n').first}',
          );
        };

        final sections = visibleSections(snapshotOf(SeededRoles.developer));
        final tabs = splitPhoneTabs(sections);
        final suffix = dark ? '-night' : '';

        try {
          for (final section in tabs.primary) {
            current = section.id;
            await tester.tap(navItem(phoneLabelOf(section)));
            await idle(tester);
            await shot(tester, 'tab-${section.id}$suffix');
          }

          for (final section in tabs.secondary) {
            current = section.id;
            await tester.tap(navItem('المزيد'));
            await idle(tester);
            await tester.tap(navItem('المزيد'));
            await idle(tester);
            await reveal(tester, find.text(section.label).last);
            await tester.tap(find.text(section.label).last);
            await idle(tester);
            await shot(tester, 'more-${section.id}$suffix');
          }
        } finally {
          FlutterError.onError = previous;
        }

        expect(errors, isEmpty);
        await settle(tester);
      },
    );
  }
}
