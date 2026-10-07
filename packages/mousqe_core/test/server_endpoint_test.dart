import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// مخزنٌ آمن في الذاكرة — `flutter_secure_storage` يحتاج قناةَ منصّة.
class _MemoryTokenStore implements TokenStore {
  String? token = 'old-token';

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String> deviceUuid() async => 'device-1';
}

/// يردّ بما يُعطاه دون شبكة — ويسجّل العنوان الذي سُئل.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    this.status = 401,
    this.body = '{"message":"Unauthenticated."}',
  });

  final int status;
  final String body;
  Uri? requested;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested = options.uri;

    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fallback = 'http://10.0.2.2:8000/api/v1';

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('normalizeLocal', () {
    test('adds the scheme, the default port and the api path', () {
      expect(
        ServerEndpoint.normalizeLocal('192.168.1.10'),
        'http://192.168.1.10:8000/api/v1',
      );
    });

    test('keeps the port that was typed', () {
      expect(
        ServerEndpoint.normalizeLocal('  192.168.137.1:9000 '),
        'http://192.168.137.1:9000/api/v1',
      );
    });

    test('accepts a full url and does not double the api path', () {
      expect(
        ServerEndpoint.normalizeLocal('http://192.168.1.10:8000/api/v1/'),
        'http://192.168.1.10:8000/api/v1',
      );
    });

    test('leaves https without a forced port', () {
      expect(
        ServerEndpoint.normalizeLocal('https://mosque.local'),
        'https://mosque.local/api/v1',
      );
    });

    test('rejects what is not an address', () {
      expect(ServerEndpoint.normalizeLocal(''), isNull);
      expect(ServerEndpoint.normalizeLocal('   '), isNull);
      expect(ServerEndpoint.normalizeLocal('ftp://192.168.1.10'), isNull);
      expect(ServerEndpoint.normalizeLocal('http://'), isNull);
    });
  });

  group('selection', () {
    test('falls back to the build-time address until someone chooses', () async {
      final endpoint = ServerEndpoint(fallbackBaseUrl: fallback);
      await endpoint.load();

      expect(endpoint.baseUrl, fallback);
      expect(endpoint.usesPrimary, isFalse);
    });

    test('the primary server is nuzuln.com over https', () async {
      final endpoint = ServerEndpoint(fallbackBaseUrl: fallback);
      await endpoint.select(primary: true, local: '');

      expect(endpoint.baseUrl, 'https://nuzuln.com/api/v1');
      expect(endpoint.usesPrimary, isTrue);
    });

    test('the choice survives a restart', () async {
      await ServerEndpoint(
        fallbackBaseUrl: fallback,
      ).select(primary: false, local: '192.168.1.10:8000');

      final reopened = ServerEndpoint(fallbackBaseUrl: fallback);
      await reopened.load();

      expect(reopened.baseUrl, 'http://192.168.1.10:8000/api/v1');
      expect(reopened.localAddress, '192.168.1.10:8000');
    });

    test('keeps the local address when the primary is chosen over it', () async {
      final endpoint = ServerEndpoint(fallbackBaseUrl: fallback);
      await endpoint.select(primary: false, local: '192.168.1.10');
      await endpoint.select(primary: true, local: '192.168.1.10');

      expect(endpoint.baseUrl, ServerEndpoint.primaryBaseUrl);
      expect(endpoint.localAddress, '192.168.1.10:8000');
    });

    test('refuses a local choice without a valid address', () async {
      final endpoint = ServerEndpoint(fallbackBaseUrl: fallback);

      expect(
        () => endpoint.select(primary: false, local: 'ftp://x'),
        throwsArgumentError,
      );
      expect(endpoint.baseUrl, fallback);
    });
  });

  group('the client follows the choice', () {
    test('requests go to the chosen server without rebuilding it', () async {
      final endpoint = ServerEndpoint(fallbackBaseUrl: fallback);
      final adapter = _StubAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient.create(
        tokenStore: _MemoryTokenStore(),
        baseUrl: endpoint.baseUrl,
        baseUrlReader: () => endpoint.baseUrl,
        dio: dio,
      );

      await client.me().then((_) {}, onError: (_) {});
      expect(adapter.requested.toString(), '$fallback/auth/me');

      await endpoint.select(primary: false, local: '192.168.1.10:8000');
      await client.me().then((_) {}, onError: (_) {});
      expect(
        adapter.requested.toString(),
        'http://192.168.1.10:8000/api/v1/auth/me',
      );
    });
  });

  group('probe', () {
    test('a 401 json from the api proves it is a Nuzuln server', () async {
      final dio = Dio()..httpClientAdapter = _StubAdapter();
      final endpoint = ServerEndpoint(
        fallbackBaseUrl: fallback,
        probeClient: dio,
      );

      expect(await endpoint.probe(primary: false, local: '192.168.1.10'), isNull);
    });

    test('any other web server is not one', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter(status: 200, body: '<html></html>');
      final endpoint = ServerEndpoint(
        fallbackBaseUrl: fallback,
        probeClient: dio,
      );

      expect(
        await endpoint.probe(primary: false, local: '192.168.1.10'),
        contains('ليس خادم نزلاً'),
      );
    });

    test('an invalid local address is reported before any request', () async {
      final adapter = _StubAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpoint = ServerEndpoint(
        fallbackBaseUrl: fallback,
        probeClient: dio,
      );

      expect(await endpoint.probe(primary: false, local: ''), contains('غير صالح'));
      expect(adapter.requested, isNull);
    });
  });

  group('choose', () {
    late AppDatabase db;
    late _MemoryTokenStore tokens;
    late SessionController session;
    late ServerEndpoint endpoint;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tokens = _MemoryTokenStore();
      session = SessionController(
        db: db,
        apiClient: _MockApiClient(),
        tokenStore: tokens,
        deviceUuid: 'device-1',
        app: 'teacher',
        appLabel: 'تطبيق الأستاذ',
      );
      endpoint = ServerEndpoint(fallbackBaseUrl: fallback);
    });

    tearDown(() => db.close());

    test('a different server signs the device out and wipes its store', () async {
      await endpoint.choose(
        primary: false,
        local: '192.168.1.10:8000',
        session: session,
      );

      expect(endpoint.baseUrl, 'http://192.168.1.10:8000/api/v1');
      expect(tokens.token, isNull);
      expect(session.stage, SessionStage.signedOut);
    });

    test('the same server leaves the session alone', () async {
      // العنوانُ المحلّي المكتوب يساوي عنوانَ البناء ⇒ لا تبديلَ فعلياً.
      await endpoint.choose(
        primary: false,
        local: '10.0.2.2:8000',
        session: session,
      );

      expect(endpoint.baseUrl, fallback);
      expect(tokens.token, 'old-token');
    });

    test('is refused while operations have not reached the server', () async {
      final engine = SyncEngine(
        db: db,
        apiClient: _MockApiClient(),
        app: 'teacher',
        deviceUuid: 'device-1',
      );
      await engine.enqueue('student.save', {'student': <String, dynamic>{}});

      await expectLater(
        endpoint.choose(primary: true, local: '', session: session),
        throwsA(isA<PendingWorkBlocksSwitch>()),
      );

      expect(endpoint.baseUrl, fallback);
      expect(tokens.token, 'old-token');
    });
  });
}
