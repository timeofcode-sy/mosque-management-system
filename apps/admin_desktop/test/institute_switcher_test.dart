import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_admin_desktop/src/state/institute_switcher.dart';
import 'package:mousqe_core/mousqe_core.dart';
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
  late SyncEngine engine;
  late SessionController session;
  late SyncController sync;
  late InstituteSwitcher switcher;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    engine = SyncEngine(
      db: db,
      apiClient: api,
      app: 'admin_desktop',
      deviceUuid: 'device-1',
    );
    session = SessionController(
      db: db,
      apiClient: api,
      tokenStore: _MemoryTokenStore(),
      deviceUuid: 'device-1',
      app: 'admin_desktop',
      appLabel: 'إدارة المعهد',
    );
    sync = SyncController(engine: engine, session: session);
    switcher = InstituteSwitcher(session: session, sync: sync);

    when(() => api.bootstrap()).thenAnswer(
      (_) async => _response(
        bootstrapBody(
          permissions: SeededRoles.developer,
          instituteUuid: 'ins-2',
          instituteName: 'معهد الهدى',
        ),
      ),
    );
    when(() => api.institutes()).thenAnswer(
      (_) async => _response({
        'current': 'ins-1',
        'data': [
          {'uuid': 'ins-1', 'name': 'معهد النور', 'is_active': true},
          {'uuid': 'ins-2', 'name': 'معهد الهدى', 'is_active': true},
        ],
      }),
    );
    // دورةُ مزامنةٍ بلا تغييرات: التبديل يعيد تشغيلها، ولا يعني هذا الاختبارُ
    // بما تجلبه.
    when(() => api.syncPull(any(), any(), any())).thenAnswer(
      (_) async => _response({'server_seq': 0, 'changes': <dynamic>[]}),
    );
  });

  tearDown(() async {
    sync.dispose();
    // دورةُ المزامنة التي أطلقها `start()` قد تكون في منتصفها: تُترك تنتهي قبل
    // إغلاق المخزن، وإلا استعلمت على قاعدةٍ مغلقة.
    await Future<void>.delayed(Duration.zero);
    await db.close();
  });

  test('an account in one institute gets no switcher', () async {
    when(() => api.institutes()).thenAnswer(
      (_) async => _response({
        'current': 'ins-1',
        'data': [
          {'uuid': 'ins-1', 'name': 'معهد النور', 'is_active': true},
        ],
      }),
    );

    await switcher.load();

    expect(switcher.options, hasLength(1));
    expect(switcher.hasChoice, isFalse);
  });

  test('a device with no network keeps working, it just cannot switch', () async {
    when(() => api.institutes()).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    );

    await switcher.load();

    expect(switcher.options, isEmpty);
    expect(switcher.hasChoice, isFalse);
  });

  test('switching stops the sync loop across the wipe and starts it again',
      () async {
    await switcher.load();
    sync.start();

    await switcher.switchTo('ins-2');

    expect(session.activeInstituteUuid, 'ins-2');
    // لو بقيت الدورةُ جارية أثناء المسح لَكتبت صفوفَ المعهد القديم بعد محوها.
    expect(sync.isRunning, isTrue);
  });

  test('a refused switch leaves the loop running, not stopped mid-way',
      () async {
    await engine.enqueue('student.save', {'student': <String, dynamic>{}});
    await switcher.load();
    sync.start();

    await expectLater(
      switcher.switchTo('ins-2'),
      throwsA(isA<PendingWorkBlocksSwitch>()),
    );

    expect(session.activeInstituteUuid, isNull);
    expect(sync.isRunning, isTrue);
  });
}
