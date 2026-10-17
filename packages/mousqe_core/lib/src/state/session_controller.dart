import 'dart:async';
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
import 'device_details.dart';

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

/// يقرأ وصفَ الجهاز المرسَل مع تسجيله — [DeviceDetails.collect] افتراضاً، وبديلٌ ثابتٌ في الاختبارات.
typedef DeviceDetailsReader = Future<Map<String, Object?>> Function();

/// يختار سطحاً واحداً حين يحمل الحسابُ أكثرَ من دورٍ يخدمه التطبيقُ الموحَّد،
/// أو `null` إن عدل صاحبُه عن الدخول.
typedef SurfaceChooser = Future<String?> Function(List<String> candidates);

/// يُرمى حين يدخل التطبيقَ الموحَّدَ حسابٌ لا يحمل دوراً من أدواره — مشرفٌ مثلاً،
/// وبابُه تطبيقُ الإدارة.
class AccountNotForThisApp implements Exception {
  const AccountNotForThisApp([
    this.message = 'هذا الحساب لا يفتح هذا التطبيق — حسابات الإدارة تدخل من تطبيق الإدارة.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// يُرمى حين يعدل صاحبُ حسابٍ متعدّد الأدوار عن اختيار سطحه.
class SurfaceChoiceCancelled implements Exception {
  const SurfaceChoiceCancelled();

  String get message => 'لم يُختر حسابٌ للدخول.';

  @override
  String toString() => message;
}

/// يُرمى حين يُطلب تبديلُ المعهد والطابورُ غيرُ فارغ — [SessionController.switchInstitute].
class PendingWorkBlocksSwitch implements Exception {
  const PendingWorkBlocksSwitch(this.count, {this.server = false});

  final int count;

  /// تبديلُ الخادم لا المعهد — [SessionController.switchServer].
  final bool server;

  String get message =>
      'بقيت $count عملية لم تصل الخادم بعد. زامِن أوّلاً ثم بدّل '
      '${server ? 'الخادم' : 'المعهد'} — '
      'التبديلُ يمسح مخزنَ الجهاز، فتضيع معه.';

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
///
/// 🔄 وتطبيقُ «نزلاً» الموحَّد يخدم الأستاذ وولي الأمر والطالب معاً: يمرّر
/// [surfaces] بدل [app]، فيُحسم السطحُ **من أدوار الحساب لحظةَ الدخول** — لا من
/// بادئة اسم المستخدم — ويُحفظ في `app_state` ليقلع الجهازُ عليه.
class SessionController extends ChangeNotifier {
  SessionController({
    required AppDatabase db,
    required ApiClient apiClient,
    required TokenStore tokenStore,
    required String deviceUuid,
    String? app,
    List<String> surfaces = const [],
    required String appLabel,
    ActiveInstitute? activeInstitute,
    PushTokenReader? pushToken,
    DeviceDetailsReader? deviceDetails,
  })  : assert(
          (app != null) != surfaces.isNotEmpty,
          'إمّا app ثابتٌ وإمّا surfaces تُحسم عند الدخول — لا الاثنان.',
        ),
        _db = db,
        _apiClient = apiClient,
        _tokenStore = tokenStore,
        _deviceUuid = deviceUuid,
        _app = app,
        _surfaces = surfaces,
        _appLabel = appLabel,
        _activeInstitute = activeInstitute ?? ActiveInstitute(),
        _pushTokenReader = pushToken,
        _deviceDetails = deviceDetails ?? DeviceDetails.collect;

  /// مفتاحُ المعهد العامل في `app_state` — يُقرأ عند الإقلاع فيفتح الجهازُ على
  /// المعهد الذي أُغلق عليه، لا على معهد الحساب الأصلي.
  static const String activeInstituteKey = 'active_institute';

  /// مفتاحُ السطح المختار في `app_state` — للتطبيق الموحَّد وحده.
  static const String surfaceKey = 'surface';

  /// نسخةُ التطبيق التي سُجّل بها الجهازُ آخرَ مرّة — فيُعاد التسجيلُ مرّةً بعد كل تحديث.
  static const String registeredVersionKey = 'device_registered_version';

  final AppDatabase _db;
  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  final String _deviceUuid;
  final List<String> _surfaces;
  String? _app;
  final String _appLabel;
  final ActiveInstitute _activeInstitute;
  final PushTokenReader? _pushTokenReader;
  final DeviceDetailsReader _deviceDetails;

  SessionStage _stage = SessionStage.starting;
  BootstrapSnapshot? _snapshot;
  String? _notice;

  SessionStage get stage => _stage;

  BootstrapSnapshot? get snapshot => _snapshot;

  /// رسالةٌ تُعرض مرّةً على شاشة الدخول — «الحساب مقفل» مثلاً.
  String? get notice => _notice;

  String get deviceUuid => _deviceUuid;

  /// السطحُ العامل: ثابتُ التطبيق، أو ما حُسم عند الدخول في التطبيق الموحَّد —
  /// و`null` فيه قبل الدخول.
  String? get app => _app;

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

    if (_surfaces.isNotEmpty) {
      final surface = await _db.readAppState(surfaceKey);

      // توكنٌ بلا سطحٍ معروف لا يفتح واجهةً — يُطلب دخولٌ جديد يحسمه.
      if (!_surfaces.contains(surface)) {
        await _wipe();
        notifyListeners();
        return;
      }

      _app = surface;
    }

    _snapshot = BootstrapSnapshot.decode(
      await _db.readAppState(BootstrapSnapshot.storageKey),
    );
    _stage = SessionStage.ready;
    notifyListeners();

    // تحديثُ اللقطة محاولةٌ لا شرط: جهازٌ بلا شبكة يبقى عاملاً بما حفظه.
    await refreshSnapshot();

    // حسابٌ أُقفل أثناء الغياب يُمسح في `refreshSnapshot` — فلا تسجيلَ له.
    // ولا يُنتظر: وصفُ الجهاز قراءةُ منصّة، والإقلاعُ لا يتأخّر من أجل إحصاء.
    if (_stage == SessionStage.ready) {
      unawaited(_refreshRegistration());
    }
  }

  /// [chooseSurface] يُسأل في التطبيق الموحَّد وحده، وحين يحمل الحسابُ أكثرَ من
  /// دورٍ من [surfaces] فقط.
  Future<void> signIn({
    required String username,
    required String password,
    SurfaceChooser? chooseSurface,
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

    if (_surfaces.isNotEmpty) {
      await _resolveSurface(body, chooseSurface);
    }

    // خطوةٌ منفصلة عن الدخول عمداً: الدخول يُثبت هوية المستخدم، والتسجيل يفتح
    // مؤشّر مزامنة للجهاز ([API.md §1](../../../../../docs/API.md)).
    await _registerDevice();

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
    // `clearAll` يمسح `app_state` كلَّه، والسطحُ باقٍ بتبديل المعهد.
    await _saveSurface();
    _snapshot = null;
    notifyListeners();

    await refreshSnapshot(rethrowErrors: true);
  }

  /// تبديلُ الخادم — **يُخرج صاحبَ الجهاز ويمسح مخزنَه**.
  ///
  /// التوكنُ ومؤشّرُ `since` ومعرّفاتُ الصفوف كلُّها من الخادم السابق، ولا يعرفها
  /// الجديد: توكنٌ غريبٌ يُردّ 401، ومؤشّرٌ غريبٌ يتخطّى صفوفاً أو يُنزل ناقصاً.
  /// ولذلك يُرفض التبديلُ والطابورُ غيرُ فارغ، كتبديل المعهد تماماً.
  ///
  /// [change] هو التبديلُ نفسُه (حفظُ العنوان الجديد)؛ ينفَّذ بعد فحص الطابور
  /// وقبل المسح، فلا يبقى الجهازُ على عنوانٍ جديدٍ بجلسةٍ قديمة.
  Future<void> switchServer(Future<void> Function() change) async {
    final unsent = await _db.pendingOperations.count().getSingle();

    if (unsent > 0) {
      throw PendingWorkBlocksSwitch(unsent, server: true);
    }

    await change();
    await _wipe();
    _notice = null;
    notifyListeners();
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
    if (_surfaces.isNotEmpty) {
      // الهاتفُ العائليّ: الداخلُ بعده قد يكون الابنَ لا الأب، فلا يرث سطحَه.
      _app = null;
    }
    _stage = SessionStage.signedOut;
  }

  /// يحسم السطحَ من أدوار الحساب كما ردّها `POST /auth/login`.
  ///
  /// والحسابُ الذي لا يحمل دوراً من [_surfaces] يُخرَج فوراً ويُبطَل توكنُه: تركُه
  /// داخلاً يفتح واجهةً لا تجد نقطةً تجيبها إلا بـ403.
  Future<void> _resolveSurface(
    Map<String, dynamic> body,
    SurfaceChooser? chooseSurface,
  ) async {
    final user = (body['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final roles = (user['roles'] as List<dynamic>? ?? const []).cast<String>();
    final candidates = [
      for (final surface in _surfaces)
        if (roles.contains(surface)) surface,
    ];

    final chosen = switch (candidates) {
      [] => null,
      [final only] => only,
      // بلا مختارٍ يُؤخذ الأوّلُ بترتيب [_surfaces]؛ ومختارٌ يعيد `null` عدولٌ.
      _ when chooseSurface == null => candidates.first,
      _ => await chooseSurface(candidates),
    };

    if (chosen == null || !candidates.contains(chosen)) {
      try {
        await _apiClient.logout();
      } on Object {
        // التوكنُ يُمسح محلياً على كل حال.
      }
      await _wipe();

      throw candidates.isEmpty
          ? const AccountNotForThisApp()
          : const SurfaceChoiceCancelled();
    }

    _app = chosen;
    await _saveSurface();
  }

  Future<void> _saveSurface() async {
    if (_surfaces.isNotEmpty && _app != null) {
      await _db.writeAppState(surfaceKey, _app!);
    }
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
  /// يفتح للجهاز مؤشّرَ مزامنة ويصفه: نوعُه وصانعُه وطرازُه ونظامُه ونسخةُ التطبيق.
  ///
  /// ✅ م.7.4: توكنُ الإشعارات يمرّ من **هذه النقطة** لا من نقطةٍ ثانية —
  /// `POST /devices/register` يقبل `fcm_token` منذ م.4 ويكتبه في `devices`.
  Future<void> _registerDevice() async {
    final details = await _readDeviceDetails();

    await _apiClient.registerDevice({
      ...details,
      'device_uuid': _deviceUuid,
      'app': _app,
      if (await _pushToken() case final String token) 'fcm_token': token,
    });

    await _db.writeAppState(registeredVersionKey, _versionOf(details));
  }

  /// بعد تحديث التطبيق تتغيّر نسختُه في «الأجهزة المزامِنة» — والتسجيلُ عند الدخول
  /// وحده كان يُبقيها على نسخة أوّل دخول. محاولةٌ صامتة: جهازٌ بلا شبكة يعيدها غداً.
  Future<void> _refreshRegistration() async {
    try {
      final details = await _readDeviceDetails();

      if (await _db.readAppState(registeredVersionKey) == _versionOf(details)) {
        return;
      }

      await _registerDevice();
    } on Object catch (error) {
      debugPrint('تعذّر تحديث تسجيل الجهاز: $error');
    }
  }

  Future<Map<String, Object?>> _readDeviceDetails() async {
    try {
      return await _deviceDetails();
    } on Object {
      return {'platform': Platform.operatingSystem};
    }
  }

  static String _versionOf(Map<String, Object?> details) =>
      '${details['app_version'] ?? '?'}+${details['app_build'] ?? '?'}';

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
