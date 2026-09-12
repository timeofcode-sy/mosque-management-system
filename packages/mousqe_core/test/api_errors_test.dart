import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';

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

/// محوِّلٌ يردّ ما يُملى عليه بلا شبكة — فيمرّ الجوابُ بالمعترِض الحقيقي.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

ApiClient _clientAnswering({required int statusCode, required Object body}) {
  final dio = Dio()..httpClientAdapter = _CannedAdapter(statusCode: statusCode, body: body);

  return ApiClient.create(
    tokenStore: _MemoryTokenStore(),
    baseUrl: 'http://localhost/api/v1',
    dio: dio,
  );
}

Future<Object> _failureOf(Future<void> Function() call) async {
  try {
    await call();
  } on Object catch (error) {
    return error;
  }

  fail('يُنتظر خطأ ولم يقع.');
}

void main() {
  /// ✅ م.9.1 — الطرفُ الآخر من حدِّ المعدّل.
  ///
  /// 🔑 **ما يقرؤه الأبُ على شاشته نصُّ الخادم حرفياً** (`messageFor`)، فبناءُ
  /// رسالةٍ عربية في الخادم لا يكفي ما لم يُتحقَّق أنها تعبر المعترِضَ وتصل
  /// `fieldMessageFor` التي تركّبها الأسطحُ الأربعة كلُّها في استمارة الدخول.
  group('حدُّ المعدّل — 429', () {
    test('the account lock reaches the login form with its own sentence', () async {
      final client = _clientAnswering(
        statusCode: 429,
        body: {
          'message': 'حاولتَ مراراً. أعِد المحاولة بعد 15 دقيقة.',
          'errors': {
            'username': ['حاولتَ مراراً. أعِد المحاولة بعد 15 دقيقة.'],
          },
        },
      );

      final failure = await _failureOf(() => client.login({'username': 'student1000'}));

      expect(fieldMessageFor(failure), 'حاولتَ مراراً. أعِد المحاولة بعد 15 دقيقة.');
    });

    test('the outer ceiling reaches it in Arabic too, not as Laravel wrote it', () async {
      final client = _clientAnswering(
        statusCode: 429,
        body: {'message': 'حاولتَ مراراً. أمهِل قليلاً ثم أعد المحاولة.'},
      );

      final failure = await _failureOf(() => client.login({'username': 'student1000'}));

      expect(fieldMessageFor(failure), contains('حاولتَ مراراً'));
      expect(fieldMessageFor(failure), isNot(contains('Too Many Attempts')));
    });

    /// 🔑 و**429 ليست انقطاعاً**: `isOffline` تقيس غيابَ الجواب لا رفضَه، ولو
    /// عُدَّت انقطاعاً لقيل للأب «سيُعاد الإرسال حين تعود الشبكة» وشبكتُه عاملة،
    /// ولانتظر إرسالاً لا يقع.
    test('a refusal is not read as a network outage', () async {
      final client = _clientAnswering(
        statusCode: 429,
        body: {'message': 'حاولتَ مراراً. أمهِل قليلاً ثم أعد المحاولة.'},
      );

      final failure = await _failureOf(() => client.login({'username': 'student1000'}));

      expect(isOffline(failure), isFalse);
    });
  });

  /// حارسُ ما كان قائماً: الرسائلُ المعتادة في الدخول لم تتغيّر بإضافة 429.
  group('ما كان قبلها', () {
    test('a wrong password still shows the field message', () async {
      final client = _clientAnswering(
        statusCode: 422,
        body: {
          'message': 'بيانات الدخول غير صحيحة.',
          'errors': {
            'username': ['بيانات الدخول غير صحيحة.'],
          },
        },
      );

      final failure = await _failureOf(() => client.login({'username': 'student1000'}));

      expect(apiExceptionOf(failure), isA<ValidationException>());
      expect(fieldMessageFor(failure), 'بيانات الدخول غير صحيحة.');
    });

    test('a locked account is still classified so the app can wipe drift', () async {
      final client = _clientAnswering(
        statusCode: 403,
        body: {'message': 'هذا الحساب مقفل.'},
      );

      final failure = await _failureOf(() => client.bootstrap());

      expect(apiExceptionOf(failure), isA<AccountLockedException>());
    });
  });
}
