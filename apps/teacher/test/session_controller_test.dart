import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_teacher/src/data/bootstrap_snapshot.dart';
import 'package:mousqe_teacher/src/state/session_controller.dart';
import 'package:retrofit/retrofit.dart';

import 'support/test_institute.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// مخزنٌ آمن في الذاكرة — `flutter_secure_storage` يحتاج قناةَ منصّة لا تعمل
/// في اختبار وحدة.
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

Map<String, dynamic> _bootstrapBody({
  String? teacherUuid = TestInstitute.teacherUuid,
}) => {
  'user': {
    'name': 'أحمد بن سعيد',
    'roles': ['teacher'],
    'teacher_uuid': teacherUuid,
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
  'course': {'uuid': 'crs-1', 'name': 'دورة 1447'},
  'circles': <Map<String, dynamic>>[],
};

void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late _MemoryTokenStore tokens;
  late SessionController session;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    tokens = _MemoryTokenStore();
    session = SessionController(
      db: db,
      apiClient: api,
      tokenStore: tokens,
      deviceUuid: 'device-1',
    );
  });

  tearDown(() => db.close());

  test('signing in stores the token, registers the device, then bootstraps', () async {
    when(() => api.login(any())).thenAnswer(
      (_) async => _response({
        'token': '12|secret',
        'user': {
          'id': 41,
          'name': 'أحمد بن سعيد',
          'roles': ['teacher'],
        },
      }),
    );
    when(() => api.registerDevice(any())).thenAnswer(
      (_) async => _response({'device_uuid': 'device-1', 'last_pulled_seq': 0}),
    );
    when(() => api.bootstrap())
        .thenAnswer((_) async => _response(_bootstrapBody()));

    await session.signIn(username: 'teacher2395', password: 'secret-pass');

    expect(tokens.token, '12|secret');
    expect(session.stage, SessionStage.ready);
    expect(session.teacherUuid, TestInstitute.teacherUuid);
    // فترةُ السماح تصل في اللقطة ويحسب بها العميلُ التأخيرَ محلياً قبل الخادم.
    expect(session.graceMinutes, 7);

    final registration =
        verify(() => api.registerDevice(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(registration['device_uuid'], 'device-1');
    expect(registration['app'], 'teacher');
  });

  test('the institute colours reach the theme, and reach it offline too', () async {
    await db.writeAppState(
      BootstrapSnapshot.storageKey,
      '{"user":{"name":"أ","roles":["teacher"],"teacher_uuid":"tch-me"},'
      '"institute":{"uuid":"ins-1","name":"معهد النور","logo_path":null,'
      '"theme":{"primary":"#7d0a0a","secondary":"#ffbf9b","surface":"#ead196"},'
      '"attendance":{"late_grace_minutes":0}},'
      '"course":null,"circles":[]}',
    );
    tokens.token = '12|secret';

    // إقلاعٌ بلا شبكة: اللقطة المحفوظة وحدها.
    when(() => api.bootstrap()).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    );

    await session.restore();

    expect(session.stage, SessionStage.ready);
    expect(session.snapshot!.institute.name, 'معهد النور');
    // اللونُ المُدخَل يقع عند الدرجة الأساسية brand-600، فهو لونُ primary نفسه.
    expect(session.theme.colorScheme.primary.toARGB32(), 0xFF7D0A0A);
  });

  test(
    'an institute with no colours still gets a theme, not a blank one',
    () async {
      expect(session.snapshot, isNull);
      expect(session.theme.colorScheme.primary.toARGB32(), isNot(0));
    },
  );

  test('a locked account cuts the session and wipes the local store', () async {
    await TestInstitute.seed(db);
    tokens.token = '12|secret';
    await db.writeAppState(BootstrapSnapshot.storageKey, '{}');

    expect(await db.select(db.students).get(), isNotEmpty);

    await session.handleAccountLocked('هذا الحساب مقفل.');

    // ما بقي على الجهاز نسخةٌ من بيانات معهدٍ لم يعد صاحبُه مخوّلاً برؤيتها.
    expect(await db.select(db.students).get(), isEmpty);
    expect(await db.select(db.courseCircles).get(), isEmpty);
    expect(await db.readAppState(BootstrapSnapshot.storageKey), isNull);
    expect(tokens.token, isNull);
    expect(session.stage, SessionStage.signedOut);
    expect(session.notice, 'هذا الحساب مقفل.');
  });

  test('a 403 locked reply during bootstrap trips the same wipe', () async {
    await TestInstitute.seed(db);
    tokens.token = '12|secret';

    when(() => api.bootstrap()).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        error: const AccountLockedException('هذا الحساب مقفل.'),
      ),
    );

    await session.restore();

    expect(session.stage, SessionStage.signedOut);
    expect(await db.select(db.students).get(), isEmpty);
  });
}
