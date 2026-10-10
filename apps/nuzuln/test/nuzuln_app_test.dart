import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:nuzuln/src/app.dart';
import 'package:nuzuln/src/di/app_scope.dart';
import 'package:nuzuln/src/features/guardian/screens/children_screen.dart';
import 'package:nuzuln/src/features/student/screens/home_screen.dart';
import 'package:nuzuln/src/screens/login_screen.dart';
import 'package:retrofit/retrofit.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MemoryTokenStore implements TokenStore {
  String? token;

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

DioException _offline() => DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'no route to host',
    );

Map<String, dynamic> _bootstrap(String role) => {
      'user': {
        'name': 'أحمد بن سعيد',
        'roles': [role],
        'permissions': <String>[],
        'teacher_uuid': null,
      },
      'institute': {
        'uuid': 'ins-1',
        'name': 'معهد النور',
        'logo_path': null,
        'theme': {
          'primary': '#7d0a0a',
          'secondary': '#ffbf9b',
          'surface': '#ead196',
        },
        'attendance': {'late_grace_minutes': 7},
      },
      'course': null,
      'circles': <Map<String, dynamic>>[],
    };

void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late _MemoryTokenStore tokens;
  late NuzulDependencies dependencies;
  late int pushTokenReads;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    tokens = _MemoryTokenStore();
    pushTokenReads = 0;
    dependencies = await NuzulDependencies.create(
      endpoint: ServerEndpoint(fallbackBaseUrl: 'http://test.invalid/api/v1'),
      database: db,
      tokens: tokens,
      api: api,
      // Firebase الحقيقية لا تعمل في اختبار وحدة — والعدّ يقيس من يُسأل الإذن.
      pushToken: () async {
        pushTokenReads++;
        return 'fcm-1';
      },
    );

    when(() => api.registerDevice(any())).thenAnswer(
      (_) async => _response({'device_uuid': 'device-1', 'last_pulled_seq': 0}),
    );
    when(() => api.logout()).thenAnswer((_) async => _response(null));
    // الرئيسيّاتُ تُفتح بلا شبكة: يكفي هنا أيُّ سطحٍ فُتح، لا ما يعرضه.
    when(api.guardianChildren).thenThrow(_offline());
    when(api.studentStanding).thenThrow(_offline());
  });

  tearDown(() => db.close());

  void account(String role) {
    when(() => api.login(any())).thenAnswer(
      (_) async => _response({
        'token': '12|secret',
        'user': {'id': 41, 'name': 'أحمد بن سعيد', 'roles': [role]},
      }),
    );
    when(() => api.bootstrap()).thenAnswer((_) async => _response(_bootstrap(role)));
  }

  Future<void> signIn(WidgetTester tester, String username) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), username);
    await tester.enterText(fields.at(1), 'secret-pass');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(NuzulApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  testWidgets('a guardian account opens the guardian surface and registers for notifications', (tester) async {
    account('guardian');
    await launch(tester);

    await signIn(tester, 'guardian1000');

    expect(find.byType(ChildrenScreen), findsOneWidget);
    final registration =
        verify(() => api.registerDevice(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(registration['app'], 'guardian');
    expect(registration['fcm_token'], 'fcm-1');
  });

  /// الهاتفُ العائلي: يخرج الأبُ فيدخل الابنُ، ولا يرث شيئاً منه.
  testWidgets('signing out and back in as a student on the same phone swaps the surface', (tester) async {
    account('guardian');
    await launch(tester);
    await signIn(tester, 'guardian1000');
    expect(find.byType(ChildrenScreen), findsOneWidget);

    await dependencies.session.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await db.readAppState(SessionController.surfaceKey), isNull);

    clearInteractions(api);
    account('student');
    await signIn(tester, 'student1000');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ChildrenScreen), findsNothing);
    final registration =
        verify(() => api.registerDevice(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(registration['app'], 'student');
    // الطالبُ لا يُسأل إذنَ الإشعارات — سُئله وليُّ الأمر وحده قبله.
    expect(registration.containsKey('fcm_token'), isFalse);
    expect(pushTokenReads, 1);
  });

  testWidgets('a staff account is turned away with a pointer to the admin app', (tester) async {
    account('supervisor');
    await launch(tester);

    await signIn(tester, 'supervisor@nuzuln.com');

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('تطبيق الإدارة'), findsOneWidget);
    expect(tokens.token, isNull);
  });
}
