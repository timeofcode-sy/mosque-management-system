import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../state/session_controller.dart';

/// يقرأ عنوانَ الـ API لحظةَ الطلب — دالّةٌ لا قيمةٌ ثابتة، فتبديلُ الخادم من شاشة
/// البدء يوجّه الطلباتِ التالية بلا إعادةِ بناء العميل ومعترضاته.
typedef BaseUrlReader = String Function();

/// الخادمُ الذي يكلّمه هذا التثبيت: **الرئيسي** (`nuzuln.com`) أو **محلّيٌ** على
/// حاسوبٍ في الشبكة نفسها.
///
/// المحلّيُّ هو المسجدُ بلا إنترنت: الحاسوبُ يشغّل الخادمَ والهواتفُ تصل إليه عبر
/// الشبكة نفسها، أو عبر نقطة اتصالٍ يُنشئها الحاسوبُ ذاتُه — وفي الحالتين العنوانُ
/// IP لا اسمٌ، فلا يُعرف وقتَ البناء ويُدخَل يدوياً مرّةً ثم يُحفَظ.
///
/// [fallbackBaseUrl] ما يعمل به التطبيقُ قبل أن يختار أحدٌ شيئاً — `--dart-define`
/// وقتَ البناء. وهو **ليس** خياراً ثالثاً في الواجهة: اختيارٌ صريحٌ يغلبه دائماً.
class ServerEndpoint extends ChangeNotifier {
  ServerEndpoint({
    required this.fallbackBaseUrl,
    FlutterSecureStorage? storage,
    Dio? probeClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _probeClient = probeClient;

  static const String primaryHost = 'nuzuln.com';
  static const String primaryBaseUrl = 'https://$primaryHost/api/v1';

  /// منفذُ `php artisan serve` — يُفترض حين يُكتب العنوانُ المحلّي بلا منفذ.
  static const int defaultLocalPort = 8000;

  static const String _apiPath = '/api/v1';
  static const String _kindKey = 'mousqe.server.kind';
  static const String _localKey = 'mousqe.server.local';

  final String fallbackBaseUrl;
  final FlutterSecureStorage _storage;
  final Dio? _probeClient;

  bool? _primary;
  String? _localBaseUrl;

  /// العنوانُ الذي تُوجَّه إليه الطلباتُ الآن.
  String get baseUrl {
    return switch (_primary) {
      true => primaryBaseUrl,
      false when _localBaseUrl != null => _localBaseUrl!,
      _ => fallbackBaseUrl,
    };
  }

  bool get usesPrimary => baseUrl == primaryBaseUrl;

  /// العنوانُ المحلّي كما يكتبه الإنسان (`192.168.1.10:8000`) — ما حُفظ، وإلا ما
  /// بُني عليه التطبيقُ إن لم يكن هو الرئيسي، وإلا فارغ.
  String get localAddress {
    final base = _localBaseUrl ??
        (fallbackBaseUrl == primaryBaseUrl ? null : fallbackBaseUrl);

    return base == null ? '' : _display(base);
  }

  /// يقرأ الاختيارَ المحفوظ — قبل بناء [ApiClient] وقبل أول إطار.
  Future<void> load() async {
    final kind = await _storage.read(key: _kindKey);

    _primary = switch (kind) {
      'primary' => true,
      'local' => false,
      _ => null,
    };
    _localBaseUrl = await _storage.read(key: _localKey);
  }

  /// العنوانُ الذي سيُستعمل لو اختير هذا الخيار — لمقارنته بالحالي قبل التبديل.
  String? baseUrlFor({required bool primary, required String local}) =>
      primary ? primaryBaseUrl : normalizeLocal(local);

  /// يحفظ الاختيار. **لا يمسّ الجلسة**: استعمل [choose] إن كان في الجهاز جلسةٌ.
  Future<void> select({required bool primary, required String local}) async {
    final normalized = normalizeLocal(local);

    if (!primary && normalized == null) {
      throw ArgumentError('عنوان الخادم المحلي غير صالح.');
    }

    // العنوانُ المحلّي يُحفظ ولو اختير الرئيسي، ليجده صاحبُه حين يعود إليه.
    if (normalized != null) {
      _localBaseUrl = normalized;
      await _storage.write(key: _localKey, value: normalized);
    }

    _primary = primary;
    await _storage.write(key: _kindKey, value: primary ? 'primary' : 'local');
    notifyListeners();
  }

  /// يبدّل الخادمَ **ومعه الجلسة**: توكنٌ ومؤشّرُ مزامنةٍ ومعرّفاتُ صفوفٍ كلُّها
  /// من خادمٍ لا يعرفها الآخر — فتبديلُ الخادم يُخرج صاحبَ الجهاز ويمسح مخزنَه
  /// ([SessionController.switchServer]). وإن لم يتغيّر العنوانُ فعلاً لا يُمسّ شيء.
  Future<void> choose({
    required bool primary,
    required String local,
    required SessionController session,
  }) async {
    final target = baseUrlFor(primary: primary, local: local);

    if (target == null && !primary) {
      throw ArgumentError('عنوان الخادم المحلي غير صالح.');
    }

    if (target == baseUrl) {
      await select(primary: primary, local: local);
      return;
    }

    await session.switchServer(() => select(primary: primary, local: local));
  }

  /// يسأل الخادمَ سؤالاً بلا توكن: `GET /auth/me` يردّ 401 JSON من التطبيق نفسِه
  /// ولو لم يكن أحدٌ داخلاً، فيثبت به أن العنوانَ **خادمُ نزلاً** لا أيَّ خادم.
  ///
  /// يعيد `null` عند النجاح، وإلا رسالةً تُعرض كما هي.
  Future<String?> probe({required bool primary, required String local}) async {
    final target = baseUrlFor(primary: primary, local: local);

    if (target == null) {
      return 'عنوان الخادم المحلي غير صالح.';
    }

    final dio = _probeClient ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );

    try {
      final response = await dio.get<dynamic>(
        '$target/auth/me',
        options: Options(
          headers: {'Accept': 'application/json'},
          // نصٌّ لا JSON: خادمٌ غريبٌ يردّ HTML بترويسة JSON لا يصحّ أن ينفجر
          // التحليلُ فيُعرض كأنّه انقطاعُ شبكة.
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );

      final status = response.statusCode ?? 500;

      final body = response.data;

      if (status < 500 && body is String && body.trimLeft().startsWith('{')) {
        return null;
      }

      return 'العنوان يستجيب لكنه ليس خادم نزلاً.';
    } on DioException catch (error) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'انتهت المهلة دون ردّ — تحقّق من العنوان ومن أن الجهازين على شبكةٍ واحدة.',
        _ => 'تعذّر الوصول إلى الخادم — تحقّق من العنوان ومن تشغيل الخادم.',
      };
    }
  }

  /// يحوّل ما كتبه المستخدمُ إلى عنوان API كامل، أو `null` إن لم يكن عنواناً.
  ///
  /// يقبل `192.168.1.10` و`192.168.1.10:8000` و`http://192.168.1.10:8000` وما
  /// يُلصَق بعده من `/api/v1`. وبلا منفذٍ يُفترض [defaultLocalPort] لـhttp.
  static String? normalizeLocal(String input) {
    var text = input.trim();

    if (text.isEmpty) {
      return null;
    }

    if (!text.contains('://')) {
      text = 'http://$text';
    }

    final uri = Uri.tryParse(text);

    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'http' ? defaultLocalPort : null);

    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: port,
    ).toString() + _apiPath;
  }

  /// `message` للحقل: `null` إن كان العنوانُ مقبولاً.
  static String? validateLocal(String input) =>
      normalizeLocal(input) == null ? 'اكتب عنوان الحاسوب، مثل 192.168.1.10:8000' : null;

  /// نصٌّ يقرؤه الإنسان: `http://` يُحذف لأنه الافتراضي، و`/api/v1` لأنه مفهوم.
  static String _display(String baseUrl) {
    var text = baseUrl;

    if (text.endsWith(_apiPath)) {
      text = text.substring(0, text.length - _apiPath.length);
    }

    return text.startsWith('http://') ? text.substring('http://'.length) : text;
  }
}
