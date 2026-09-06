import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../data/bootstrap_snapshot.dart';
import 'api_errors.dart';

enum SessionStage {
  /// قبل قراءة التوكن من المخزن الآمن.
  starting,

  signedOut,

  ready,
}

/// هويّة صاحب الجهاز وحالةُ دخوله ولقطةُ معهده.
///
/// هذه الطبقة وحدها تلمس `/auth/*` و`/bootstrap`؛ كل ما عداها يقرأ drift.
class SessionController extends ChangeNotifier {
  SessionController({
    required AppDatabase db,
    required ApiClient apiClient,
    required TokenStore tokenStore,
    required String deviceUuid,
  }) : _db = db,
       _apiClient = apiClient,
       _tokenStore = tokenStore,
       _deviceUuid = deviceUuid;

  final AppDatabase _db;
  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  final String _deviceUuid;

  SessionStage _stage = SessionStage.starting;
  BootstrapSnapshot? _snapshot;
  String? _notice;

  SessionStage get stage => _stage;

  BootstrapSnapshot? get snapshot => _snapshot;

  /// رسالةٌ تُعرض مرّةً على شاشة الدخول — «الحساب مقفل» مثلاً.
  String? get notice => _notice;

  String get deviceUuid => _deviceUuid;

  String? get teacherUuid => _snapshot?.teacherUuid;

  int get graceMinutes => _snapshot?.institute.attendance.lateGraceMinutes ?? 0;

  /// ثيمُ المعهد الثلاثي، أو لوحة `design-tokens.json` لمعهدٍ لم يضبط ألوانه
  /// (والخادم يبعث الافتراضية دائماً، فالفرع الثاني للإقلاع قبل أول لقطة).
  ThemeData get theme {
    final institute = _snapshot?.institute;

    if (institute == null) {
      return MousqeTheme.fallback();
    }

    return MousqeTheme.fromColors(
      primary: institute.theme.primary,
      secondary: institute.theme.secondary,
      surface: institute.theme.surface,
    );
  }

  /// أول ما يُستدعى عند الإقلاع: توكنٌ محفوظ + لقطةٌ محفوظة ⇒ واجهةٌ عاملة
  /// قبل أي طلب شبكة.
  Future<void> restore() async {
    final token = await _tokenStore.readToken();

    if (token == null) {
      _stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }

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
      'app': AppConfig.app,
      'platform': Platform.operatingSystem,
      'app_version': '1.0.0',
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
    _snapshot = null;
    _stage = SessionStage.signedOut;
  }

  String _deviceName() {
    final model = defaultTargetPlatform.name;

    return 'تطبيق الأستاذ · $model';
  }
}
