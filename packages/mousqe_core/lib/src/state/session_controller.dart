import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../api/api_exception.dart';
import '../api/token_store.dart';
import '../db/database.dart';
import '../models/bootstrap_snapshot.dart';
import '../models/institute_option.dart';

enum SessionStage {
  /// قبل قراءة التوكن من المخزن الآمن.
  starting,

  signedOut,

  ready,
}

/// المعهد العامل على هذا الجهاز — يُقرأ عند **كل طلب** فتحمله ترويسة `X-Institute`.
///
/// كائنٌ صغير مستقلّ لا حقلٌ في [SessionController]، لأن [ApiClient] يُبنى قبل
/// المتحكّم ويقرأ منه: هو الوصلةُ التي تكسر دورةَ الاعتماد بين الاثنين.
class ActiveInstitute {
  ActiveInstitute([this.uuid]);

  String? uuid;
}

/// يقرأ توكنَ الإشعارات لحظةَ الدخول — ✅ م.7.4.
///
/// دالّةٌ يمرّرها التطبيق لا اعتمادٌ على `firebase_messaging` في `mousqe_core`:
/// الحزمةُ طبقةُ بياناتٍ تخدم أربعة تطبيقات، ولا يحتاج ثلاثةٌ منها Firebase.
/// وتطبيقٌ لا يمرّرها يرسل تسجيلَ جهازه بلا الحقل كما كان — والخادمُ يقبله
/// اختيارياً منذ م.4.
///
/// وتعيد `null` حين يرفض المستخدمُ إذنَ الإشعارات أو حين لا تصل الشبكة إلى FCM —
/// **وذاك ليس خطأً يُوقف الدخول**: من رفض الإشعارات يدخل التطبيقَ ويستعمله.
typedef PushTokenReader = Future<String?> Function();

/// يُرمى حين يُطلب تبديلُ المعهد والطابورُ غيرُ فارغ — [SessionController.switchInstitute].
class PendingWorkBlocksSwitch implements Exception {
  const PendingWorkBlocksSwitch(this.count);

  final int count;

  String get message =>
      'بقيت $count عملية لم تصل الخادم بعد. زامِن أوّلاً ثم بدّل المعهد — '
      'تبديلُ المعهد يمسح مخزنَ الجهاز، فتضيع معه.';

  @override
  String toString() => message;
}

/// هويّة صاحب الجهاز وحالةُ دخوله ولقطةُ معهده — والمعهدُ الذي يعمل فيه الآن.
///
/// هذه الطبقة وحدها تلمس `/auth/*` و`/bootstrap` و`/institutes`؛ كل ما عداها
/// يقرأ drift.
///
/// 🔄 م.6.3 — رُفعت من `apps/teacher/` إلى الحزمة حين احتاجها الديسكتوب: ما
/// يختلف بين التطبيقين معاملان ([app] و[appLabel])، وما زاد عليها هو مبدّلُ
/// المعاهد وحده ([ARCHITECTURE.md §6](../../../../../docs/ARCHITECTURE.md)).
class SessionController extends ChangeNotifier {
  SessionController({
    required AppDatabase db,
    required ApiClient apiClient,
    required TokenStore tokenStore,
    required String deviceUuid,
    required String app,
    required String appLabel,
    ActiveInstitute? activeInstitute,
    PushTokenReader? pushToken,
  })  : _db = db,
        _apiClient = apiClient,
        _tokenStore = tokenStore,
        _deviceUuid = deviceUuid,
        _app = app,
        _appLabel = appLabel,
        _activeInstitute = activeInstitute ?? ActiveInstitute(),
        _pushTokenReader = pushToken;

  /// مفتاحُ المعهد العامل في `app_state` — يُقرأ عند الإقلاع فيفتح الجهازُ على
  /// المعهد الذي أُغلق عليه، لا على معهد الحساب الأصلي.
  static const String activeInstituteKey = 'active_institute';

  final AppDatabase _db;
  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  final String _deviceUuid;
  final String _app;
  final String _appLabel;
  final ActiveInstitute _activeInstitute;
  final PushTokenReader? _pushTokenReader;

  SessionStage _stage = SessionStage.starting;
  BootstrapSnapshot? _snapshot;
  String? _notice;

  SessionStage get stage => _stage;

  BootstrapSnapshot? get snapshot => _snapshot;

  /// رسالةٌ تُعرض مرّةً على شاشة الدخول — «الحساب مقفل» مثلاً.
  String? get notice => _notice;

  String get deviceUuid => _deviceUuid;

  String? get teacherUuid => _snapshot?.teacherUuid;

  /// uuid المعهد العامل، أو `null` إن كان معهدَ الحساب الأصلي بلا تبديل.
  String? get activeInstituteUuid => _activeInstitute.uuid;

  int get graceMinutes => _snapshot?.lateGraceMinutes ?? 0;

  /// هل يملك صاحبُ الجهاز هذه الصلاحية في معهده العامل؟ — عليها تُبنى الأبواب.
  bool can(String permission) => _snapshot?.can(permission) ?? false;

  /// أول ما يُستدعى عند الإقلاع: توكنٌ محفوظ + لقطةٌ محفوظة ⇒ واجهةٌ عاملة
  /// قبل أي طلب شبكة.
  Future<void> restore() async {
    final token = await _tokenStore.readToken();

    if (token == null) {
      _stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }

    // المعهدُ العامل قبل اللقطة: هو ما تحمله ترويسةُ أوّل طلب، فلو قُرئ بعدها
    // لَجاءت اللقطةُ من معهدٍ آخر ثم صحّحها طلبٌ ثانٍ أمام عين المستخدم.
    _activeInstitute.uuid = _blankToNull(
      await _db.readAppState(activeInstituteKey),
    );
    _snapshot = BootstrapSnapshot.decode(
      await _db.readAppState(BootstrapSnapshot.storageKey),
    );
    _stage = SessionStage.ready;
    notifyListeners();

    // تحديثُ اللقطة محاولةٌ لا شرط: جهازٌ بلا شبكة يبقى عاملاً بما حفظه.
    await refreshSnapshot();
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    // دخولٌ جديد يبدأ من معهد الحساب الأصلي: اختيارُ مستخدمٍ سابق على هذا الجهاز
    // لا يعني شيئاً للداخل الآن، وترويسةٌ بمعهدٍ لا يعمل فيه تُردّ 403.
    await _saveActiveInstitute(null);

    final response = await _apiClient.login({
      'username': username,
      'password': password,
      'device_name': _deviceName(),
    });

    final body = (response.data as Map).cast<String, dynamic>();
    await _tokenStore.saveToken(body['token'] as String);

    // خطوةٌ منفصلة عن الدخول عمداً: الدخول يُثبت هوية المستخدم، والتسجيل يفتح
    // مؤشّر مزامنة للجهاز ([API.md §1](../../../../../docs/API.md)).
    await _apiClient.registerDevice({
      'device_uuid': _deviceUuid,
      'app': _app,
      'platform': Platform.operatingSystem,
      'app_version': '1.0.0',
      // ✅ م.7.4: توكنُ الإشعارات يمرّ من **هذه النقطة** لا من نقطةٍ ثانية —
      // `POST /devices/register` يقبل `fcm_token` منذ م.4 ويكتبه في `devices`،
      // وهو يُستدعى هنا عند كل دخول: أي في اللحظة التي يصير فيها للجهاز صاحبٌ
      // معروف. ونقطةٌ مستقلّة للتوكن كانت ستضاعف ما هو مبنيّ.
      if (await _pushToken() case final String token) 'fcm_token': token,
    });

    await refreshSnapshot(rethrowErrors: true);
    _notice = null;
    _stage = SessionStage.ready;
    notifyListeners();
  }

  Future<void> refreshSnapshot({bool rethrowErrors = false}) async {
    try {
      final response = await _apiClient.bootstrap();
      final raw = jsonEncode(response.data);

      await _db.writeAppState(BootstrapSnapshot.storageKey, raw);
      _snapshot = BootstrapSnapshot.decode(raw);
      notifyListeners();
    } on Object catch (error) {
      final api = apiExceptionOf(error);

      if (api is AccountLockedException || api is UnauthenticatedException) {
        await handleAccountLocked(api!.message);
        return;
      }

      if (rethrowErrors) {
        rethrow;
      }
    }
  }

  /// المعاهد التي يحقّ لصاحب الحساب أن يعمل فيها — قائمةُ مبدّل المعاهد.
  ///
  /// من الشبكة لا من drift: ما يصل في `sync/pull` هو صفُّ المعهد العامل وحده،
  /// فلا يعرف الجهازُ عن غيره شيئاً قبل أن يسأل.
  Future<List<InstituteOption>> institutes() async {
    final response = await _apiClient.institutes();
    final body = (response.data as Map).cast<String, dynamic>();

    return [
      for (final row in body['data'] as List<dynamic>? ?? const [])
        InstituteOption.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// تبديلُ المعهد العامل — **يمسح مخزنَ الجهاز ويعيد السحب من الصفر**.
  ///
  /// لأن `sync/pull` يرشّح بـ`scope_key = institute:{uuid}` ومؤشّرُ `since` رقمٌ
  /// عامّ في `change_log`: لو بقي المؤشّرُ من معهدٍ سابق لَتخطّى صفوفَ المعهد
  /// الجديد الأقدمَ منه، فيفتح الجهازُ على معهدٍ ناقص لا يشكو من شيء.
  ///
  /// ويُرفض التبديلُ والطابورُ غيرُ فارغ: عملياتُ المعهد السابق تُمسح معه، ولو
  /// أُرسلت بعد التبديل لَردّها حاجزُ المعهد في الخادم واحدةً واحدة.
  Future<void> switchInstitute(String instituteUuid) async {
    if (instituteUuid == _activeInstitute.uuid) {
      return;
    }

    final unsent = await _db.pendingOperations.count().getSingle();

    if (unsent > 0) {
      throw PendingWorkBlocksSwitch(unsent);
    }

    await _db.clearAll();
    await _saveActiveInstitute(instituteUuid);
    _snapshot = null;
    notifyListeners();

    await refreshSnapshot(rethrowErrors: true);
  }

  Future<void> signOut() async {
    try {
      await _apiClient.logout();
    } on Object {
      // إبطالُ التوكن على الخادم مفيدٌ لا لازم: الخروجُ محلياً يتمّ في الحالتين.
    }

    await _wipe();
    _notice = null;
    notifyListeners();
  }

  /// `403 هذا الحساب مقفل` ⇒ مسحُ المخزن المحلي وطلبُ دخولٍ جديد
  /// ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 10).
  ///
  /// المسحُ ليس تشدّداً: التوكن أُبطل على الخادم، فما بقي على الجهاز نسخةٌ من
  /// بيانات معهدٍ لم يعد صاحبُ الجهاز مخوّلاً برؤيتها.
  Future<void> handleAccountLocked([String? message]) async {
    await _wipe();
    _notice = message ?? 'هذا الحساب مقفل.';
    notifyListeners();
  }

  Future<void> _wipe() async {
    await _tokenStore.clearToken();
    await _db.clearAll();
    _activeInstitute.uuid = null;
    _snapshot = null;
    _stage = SessionStage.signedOut;
  }

  /// يُكتب في drift **وفي الذاكرة معاً**: الأولى ليصمد الاختيار عبر الإقلاع،
  /// والثانية ليحمله أوّلُ طلبٍ بعده بلا قراءةٍ من القرص في كل معترض.
  Future<void> _saveActiveInstitute(String? uuid) async {
    _activeInstitute.uuid = uuid;
    await _db.writeAppState(activeInstituteKey, uuid ?? '');
  }

  /// توكنُ الإشعارات، أو `null` — **ولا يُسقط الدخولَ مهما وقع**.
  ///
  /// من رفض إذنَ الإشعارات، ومن دخل وFCM غيرُ قابلٍ للوصول، يدخلان التطبيقَ
  /// ويستعملانه كاملاً. الإشعارُ ميزةٌ فوق الوظيفة لا شرطٌ لها.
  Future<String?> _pushToken() async {
    if (_pushTokenReader == null) {
      return null;
    }

    try {
      final token = await _pushTokenReader();

      return (token == null || token.isEmpty) ? null : token;
    } on Object {
      return null;
    }
  }

  static String? _blankToNull(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  String _deviceName() => '$_appLabel · ${defaultTargetPlatform.name}';
}
