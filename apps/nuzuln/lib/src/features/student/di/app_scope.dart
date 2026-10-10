import 'package:flutter/widgets.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../../../config.dart';

/// اعتماديات التطبيق، مبنيّةً مرّةً عند الإقلاع.
///
/// **خمسةٌ لا سبعة**، كتطبيق ولي الأمر: لا `SyncEngine` ولا `SyncController`.
/// والطالبُ أفقرُ منه صلاحيةً — **لا كتابةَ إطلاقاً**، ولا حتى كتابةً متّصلةً
/// كتقديم الإذن؛ وليّ أمره يقدّمه لا هو
/// ([APPS-FEATURES.md §6.3](../../../../../../../docs/APPS-FEATURES.md)).
///
/// 🔄 في تطبيق «نزلاً» الموحَّد يبنيها `NuzulDependencies` من المخزن والعميل
/// والجلسة المشتركة؛ و[create] باقٍ لاختبارات هذا السطح وحده.
class AppDependencies {
  AppDependencies({
    required this.db,
    required this.tokenStore,
    required this.endpoint,
    required this.apiClient,
    required this.repository,
    required this.session,
  });

  final AppDatabase db;
  final TokenStore tokenStore;

  /// الخادمُ الذي يكلّمه هذا التثبيت — يُبدَّل من شاشة البدء ([ServerEndpoint]).
  final ServerEndpoint endpoint;
  final ApiClient apiClient;
  final StudentSelfRepository repository;
  final SessionController session;

  static Future<AppDependencies> create({
    AppDatabase? database,
    TokenStore? tokens,
    ApiClient? api,
    ServerEndpoint? endpoint,
    String baseUrl = AppConfig.baseUrl,
  }) async {
    final db = database ?? AppDatabase();
    final tokenStore = tokens ?? TokenStore();
    final deviceUuid = await tokenStore.deviceUuid();
    // قبل بناء العميل: عنوانُه الأولُ هو ما اختاره صاحبُ الجهاز في المرّة السابقة
    // إن اختار، وإلا عنوانُ البناء.
    final server = endpoint ?? ServerEndpoint(fallbackBaseUrl: baseUrl);
    if (endpoint == null) {
      await server.load();
    }

    final apiClient = api ??
        ApiClient.create(
          tokenStore: tokenStore,
          baseUrl: server.baseUrl,
          baseUrlReader: () => server.baseUrl,
        );

    return AppDependencies(
      db: db,
      tokenStore: tokenStore,
      endpoint: server,
      apiClient: apiClient,
      repository: StudentSelfRepository(db: db, apiClient: apiClient),
      session: SessionController(
        db: db,
        apiClient: apiClient,
        tokenStore: tokenStore,
        deviceUuid: deviceUuid,
        app: Surface.student,
        appLabel: AppConfig.label,
      ),
    );
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope غير موجود فوق هذه الشاشة.');

    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
