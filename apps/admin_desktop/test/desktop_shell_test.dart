import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_admin_desktop/src/di/app_scope.dart';
import 'package:mousqe_admin_desktop/src/shell/desktop_shell.dart';
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

void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late AppDependencies dependencies;

  /// اعتمادياتٌ حقيقية بمخزنٍ في الذاكرة وعميلٍ مُقلَّد — لا قناةَ منصّة في
  /// اختبار وحدة، فالنافذةُ والمخزنُ الآمن خارج هذه الشجرة.
  Future<void> boot(List<String> permissions) async {
    final activeInstitute = ActiveInstitute();
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
      activeInstitute: activeInstitute,
    );
    final sync = SyncController(engine: engine, session: session);

    when(() => api.bootstrap()).thenAnswer(
      (_) async => _response(bootstrapBody(permissions: permissions)),
    );

    dependencies = AppDependencies(
      db: db,
      tokenStore: tokens,
      apiClient: api,
      syncEngine: engine,
      session: session,
      sync: sync,
      institutes: InstituteSwitcher(session: session, sync: sync),
    );

    await session.restore();
  }

  Widget shell() => AppScope(
        dependencies: dependencies,
        child: MousqeApp(
          theme: MousqeTheme.fallback(),
          home: const DesktopShell(),
        ),
      );

  /// نافذةٌ بمقاس الحدّ الأدنى الحقيقي: القائمةُ الجانبية قائمةٌ متمرّرة، ولو
  /// اختُبرت في 800×600 الافتراضية لَسقطت أبوابٌ تحت الطيّة فبدت غائبةً وهي
  /// ظاهرةٌ لصاحبها.
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(shell());
    await tester.pump();
  }

  /// تفكيكُ الشجرة **داخل** الاختبار ثم تمريرُ الزمن.
  ///
  /// تدفّقاتُ drift تُبقي مؤقّتَ إبقاءٍ قصيراً بعد انصراف آخر مستمع (شريطُ
  /// المزامنة يستمع إلى ثلاثة منها)، وإطارُ الاختبار يفحص المؤقّتات المعلّقة قبل
  /// أن تصل `tearDown`. فلو تُركت الشجرةُ قائمةً لَسقط كلُّ اختبارٍ فيه شريط.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 15));
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
  });

  tearDown(() => db.close());

  testWidgets('the sidebar carries the doors the account owns and no others',
      (tester) async {
    await boot(SeededRoles.supervisor);
    await pumpShell(tester);

    expect(find.text('التفقّد'), findsOneWidget);
    expect(find.text('أعذار الغياب'), findsOneWidget);
    expect(find.text('بيانات الدخول'), findsOneWidget);

    // بابٌ لا يملكه المشرف لا يظهر معطَّلاً — لا يظهر أصلاً.
    expect(find.text('المستخدمون والأدوار'), findsNothing);
    expect(find.text('المعاهد'), findsNothing);
    await settle(tester);
  });

  testWidgets('the institute admin gets the institute doors, minus institutes',
      (tester) async {
    await boot(SeededRoles.admin);
    await pumpShell(tester);

    expect(find.text('المستخدمون والأدوار'), findsOneWidget);
    expect(find.text('بيانات المعهد'), findsOneWidget);
    expect(find.text('المعاهد'), findsNothing);
    await settle(tester);
  });

  testWidgets('the institute name and running course head the sidebar',
      (tester) async {
    await boot(SeededRoles.supervisor);
    await pumpShell(tester);

    expect(find.text('معهد النور'), findsOneWidget);
    expect(find.text('دورة 1447'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('the switcher stays hidden for an account with one institute',
      (tester) async {
    await boot(SeededRoles.admin);
    when(() => api.institutes()).thenAnswer(
      (_) async => _response({
        'current': 'ins-1',
        'data': [
          {'uuid': 'ins-1', 'name': 'معهد النور', 'is_active': true},
        ],
      }),
    );
    await dependencies.institutes.load();

    await pumpShell(tester);

    expect(find.byTooltip('بدّل المعهد'), findsNothing);
    await settle(tester);
  });

  testWidgets('and shows for one who works in more than one', (tester) async {
    await boot(SeededRoles.developer);
    when(() => api.institutes()).thenAnswer(
      (_) async => _response({
        'current': 'ins-1',
        'data': [
          {'uuid': 'ins-1', 'name': 'معهد النور', 'is_active': true},
          {'uuid': 'ins-2', 'name': 'معهد الهدى', 'is_active': true},
        ],
      }),
    );
    await dependencies.institutes.load();

    await pumpShell(tester);

    expect(find.byTooltip('بدّل المعهد'), findsOneWidget);

    await tester.tap(find.byTooltip('بدّل المعهد'));
    await tester.pumpAndSettle();

    expect(find.text('معهد الهدى'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('an account with no permission in this institute sees why',
      (tester) async {
    await boot(const []);
    await pumpShell(tester);

    expect(find.textContaining('لا تملك صلاحيةً واحدة'), findsOneWidget);
    expect(find.text('خروج'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('each door keeps its own stack, so leaving one does not reset it',
      (tester) async {
    await boot(SeededRoles.admin);
    await pumpShell(tester);

    final sections = tester.widgetList<IndexedStack>(find.byType(IndexedStack));

    // بابٌ واحد ظاهر، وبقيّةُ الأبواب حيّةٌ خلفه في نفس المكدّس — وهي العلّةُ
    // التي جعلت `IndexedStack` بديلاً كافياً عن `StatefulShellRoute`.
    expect(sections, hasLength(1));
    expect(sections.single.children, hasLength(greaterThan(1)));
    await settle(tester);
  });
}
