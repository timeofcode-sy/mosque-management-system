import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:retrofit/retrofit.dart';

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
  String? teacherUuid = 'tch-me',
  String instituteUuid = 'ins-1',
  String instituteName = 'معهد النور',
  List<String> permissions = const ['circles.view', 'sync.pull'],
}) => {
  'user': {
    'name': 'أحمد بن سعيد',
    'roles': ['teacher'],
    'permissions': permissions,
    'teacher_uuid': teacherUuid,
  },
  'institute': {
    'uuid': instituteUuid,
    'name': instituteName,
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

/// يهيّئ الردودَ الثلاثة التي يمرّ بها [SessionController.signIn].
void _stubSignIn(_MockApiClient api) {
  when(() => api.login(any())).thenAnswer(
    (_) async => _response({
      'token': '12|secret',
      'user': {'id': 41, 'name': 'أحمد بن سعيد', 'roles': ['guardian']},
    }),
  );
  when(() => api.registerDevice(any())).thenAnswer(
    (_) async => _response({'device_uuid': 'device-1', 'last_pulled_seq': 0}),
  );
  when(() => api.bootstrap())
      .thenAnswer((_) async => _response(_bootstrapBody()));
}

void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late _MemoryTokenStore tokens;
  late ActiveInstitute activeInstitute;
  late SessionController session;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    tokens = _MemoryTokenStore();
    activeInstitute = ActiveInstitute();
    session = SessionController(
      db: db,
      apiClient: api,
      tokenStore: tokens,
      deviceUuid: 'device-1',
      app: 'teacher',
      appLabel: 'تطبيق الأستاذ',
      activeInstitute: activeInstitute,
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
    expect(session.teacherUuid, 'tch-me');
    // فترةُ السماح تصل في اللقطة ويحسب بها العميلُ التأخيرَ محلياً قبل الخادم.
    expect(session.graceMinutes, 7);

    final registration =
        verify(() => api.registerDevice(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(registration['device_uuid'], 'device-1');
    // اسمُ التطبيق معاملٌ لا ثابتٌ في الحزمة — الديسكتوب يسجّل نفسه بـ`admin_desktop`.
    expect(registration['app'], 'teacher');
    // ✅ م.7.4: تطبيقٌ لا يمرّر قارئَ التوكن يسجّل جهازَه **بلا الحقل** كما كان.
    expect(registration.containsKey('fcm_token'), isFalse);
  });

  /// ✅ م.7.4 — التوكنُ يمرّ من نقطة تسجيل الجهاز القائمة لا من نقطةٍ ثانية.
  test('a push token, when the app can read one, rides along with the device registration', () async {
    session = SessionController(
      db: db,
      apiClient: api,
      tokenStore: tokens,
      deviceUuid: 'device-1',
      app: 'guardian',
      appLabel: 'تطبيق ولي الأمر',
      activeInstitute: activeInstitute,
      pushToken: () async => 'fcm-abc123',
    );

    _stubSignIn(api);

    await session.signIn(username: 'guardian55', password: 'secret-pass');

    final registration =
        verify(() => api.registerDevice(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(registration['fcm_token'], 'fcm-abc123');
    expect(registration['app'], 'guardian');
  });

  /// 🔑 **من رفض الإشعارات يدخل التطبيق**: القارئُ يرمي أو يعيد `null`، والدخولُ
  /// يمضي بلا الحقل — الإشعارُ ميزةٌ فوق الوظيفة لا شرطٌ لها.
  test('a refused or failing push token never blocks the sign-in', () async {
    for (final reader in <PushTokenReader>[
      () async => null,
      () async => '',
      () async => throw StateError('المستخدم رفض إذن الإشعارات'),
    ]) {
      api = _MockApiClient();
      session = SessionController(
        db: db,
        apiClient: api,
        tokenStore: tokens,
        deviceUuid: 'device-1',
        app: 'guardian',
        appLabel: 'تطبيق ولي الأمر',
        activeInstitute: ActiveInstitute(),
        pushToken: reader,
      );

      _stubSignIn(api);

      await session.signIn(username: 'guardian55', password: 'secret-pass');

      expect(session.stage, SessionStage.ready);

      final registration =
          verify(() => api.registerDevice(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(registration.containsKey('fcm_token'), isFalse);
    }
  });

  test('the institute colours reach the snapshot, and reach it offline too', () async {
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
    expect(session.snapshot!.institute.theme.primary, '#7d0a0a');
  });

  test('a snapshot from a server older than 6.1 opens no doors, not every door', () async {
    final snapshot = BootstrapSnapshot.fromJson(<String, dynamic>{
      'user': {'name': 'أ', 'roles': ['supervisor']},
      'institute': {
        'uuid': 'ins-1',
        'name': 'معهد النور',
        'theme': {
          'primary': '#0F5132',
          'secondary': '#C9A227',
          'surface': '#F7F3EA',
        },
        'attendance': {'late_grace_minutes': 0},
      },
      'course': null,
      'circles': <dynamic>[],
    });

    expect(snapshot.permissions, isEmpty);
    expect(snapshot.can('students.manage'), isFalse);
  });

  test('a locked account cuts the session and wipes the local store', () async {
    tokens.token = '12|secret';
    await db.writeAppState(BootstrapSnapshot.storageKey, '{}');
    await db.writeAppState(SessionController.activeInstituteKey, 'ins-2');
    activeInstitute.uuid = 'ins-2';

    await session.handleAccountLocked('هذا الحساب مقفل.');

    // ما بقي على الجهاز نسخةٌ من بيانات معهدٍ لم يعد صاحبُه مخوّلاً برؤيتها.
    expect(await db.readAppState(BootstrapSnapshot.storageKey), isNull);
    expect(tokens.token, isNull);
    expect(session.stage, SessionStage.signedOut);
    expect(session.notice, 'هذا الحساب مقفل.');
    // ولا تبقى ترويسةُ معهدٍ معلَّقة على الطلب الأول بعد دخولٍ جديد.
    expect(activeInstitute.uuid, isNull);
  });

  test('a 403 locked reply during bootstrap trips the same wipe', () async {
    tokens.token = '12|secret';
    await db.writeAppState(BootstrapSnapshot.storageKey, '{}');

    when(() => api.bootstrap()).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        error: const AccountLockedException('هذا الحساب مقفل.'),
      ),
    );

    await session.restore();

    expect(session.stage, SessionStage.signedOut);
    expect(await db.readAppState(BootstrapSnapshot.storageKey), isNull);
  });

  group('institute switcher', () {
    setUp(() {
      when(() => api.institutes()).thenAnswer(
        (_) async => _response({
          'current': 'ins-1',
          'data': [
            {'uuid': 'ins-1', 'name': 'معهد النور', 'logo_path': null, 'is_active': true},
            {'uuid': 'ins-2', 'name': 'معهد الهدى', 'logo_path': null, 'is_active': false},
          ],
        }),
      );
      when(() => api.bootstrap()).thenAnswer(
        (_) async => _response(
          _bootstrapBody(instituteUuid: 'ins-2', instituteName: 'معهد الهدى'),
        ),
      );
    });

    test('the list comes from the network — pull only ever carries one institute', () async {
      final institutes = await session.institutes();

      expect(institutes, hasLength(2));
      expect(institutes.last.name, 'معهد الهدى');
      // معهدٌ موقوف يبقى في القائمة معلَّماً: المبرمج يفتحه ليعيد تفعيله.
      expect(institutes.last.isActive, isFalse);
    });

    test('switching wipes the store, resets the cursor and re-bootstraps', () async {
      await db.into(db.syncState).insert(
            SyncStateCompanion.insert(
              deviceUuid: 'device-1',
              lastPulledSeq: const Value(9140),
            ),
          );
      await db.into(db.institutes).insert(
            InstitutesCompanion.insert(id: const Value(1), uuid: 'ins-1', name: 'معهد النور'),
          );

      await session.switchInstitute('ins-2');

      // مؤشّرٌ من معهدٍ سابق كان سيتخطّى صفوفَ المعهد الجديد الأقدمَ منه.
      expect(await db.select(db.syncState).get(), isEmpty);
      expect(await db.select(db.institutes).get(), isEmpty);
      expect(session.activeInstituteUuid, 'ins-2');
      expect(session.snapshot!.institute.name, 'معهد الهدى');
      // ويصمد الاختيارُ عبر الإقلاع، فلا يعود الجهازُ إلى معهد الحساب الأصلي.
      expect(await db.readAppState(SessionController.activeInstituteKey), 'ins-2');
    });

    test('an unsent queue blocks the switch instead of being wiped with the store', () async {
      final engine = SyncEngine(
        db: db,
        apiClient: api,
        app: 'admin_desktop',
        deviceUuid: 'device-1',
      );
      await engine.enqueue('student.save', {'student': <String, dynamic>{}});

      await expectLater(
        session.switchInstitute('ins-2'),
        throwsA(isA<PendingWorkBlocksSwitch>()),
      );

      expect(session.activeInstituteUuid, isNull);
      expect(await db.select(db.pendingOperations).get(), hasLength(1));
    });

    test('an isolated operation blocks it too — it is a write no one has accepted', () async {
      final engine = SyncEngine(
        db: db,
        apiClient: api,
        app: 'admin_desktop',
        deviceUuid: 'device-1',
      );
      final opUuid = await engine.enqueue('enrollment.save', <String, dynamic>{});
      await (db.update(db.pendingOperations)..where((t) => t.opUuid.equals(opUuid)))
          .write(PendingOperationsCompanion(
        failedReason: const Value('لا تملك صلاحية هذه العملية.'),
        failedAt: Value(DateTime.now()),
      ));

      await expectLater(
        session.switchInstitute('ins-2'),
        throwsA(isA<PendingWorkBlocksSwitch>()),
      );
    });

    test('the restored institute is read before the first request goes out', () async {
      tokens.token = '12|secret';
      await db.writeAppState(SessionController.activeInstituteKey, 'ins-2');

      await session.restore();

      expect(activeInstitute.uuid, 'ins-2');
    });
  });
}
