import 'package:flutter/widgets.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../config.dart';

/// اعتماديات التطبيق، مبنيّةً مرّةً عند الإقلاع.
///
/// **خمسةٌ لا سبعة**، كتطبيق ولي الأمر: لا `SyncEngine` ولا `SyncController`.
/// والطالبُ أفقرُ منه صلاحيةً — **لا كتابةَ إطلاقاً**، ولا حتى كتابةً متّصلةً
/// كتقديم الإذن؛ وليّ أمره يقدّمه لا هو
/// ([APPS-FEATURES.md §6.3](../../../../../docs/APPS-FEATURES.md)).
class AppDependencies {
  AppDependencies({
    required this.db,
    required this.tokenStore,
    required this.apiClient,
    required this.repository,
    required this.session,
  });

  final AppDatabase db;
  final TokenStore tokenStore;
  final ApiClient apiClient;
  final StudentSelfRepository repository;
  final SessionController session;

  static Future<AppDependencies> create({
    AppDatabase? database,
    TokenStore? tokens,
    ApiClient? api,
    String baseUrl = AppConfig.baseUrl,
  }) async {
    final db = database ?? AppDatabase();
    final tokenStore = tokens ?? TokenStore();
    final deviceUuid = await tokenStore.deviceUuid();
    final apiClient = api ?? ApiClient.create(tokenStore: tokenStore, baseUrl: baseUrl);

    return AppDependencies(
      db: db,
      tokenStore: tokenStore,
      apiClient: apiClient,
      repository: StudentSelfRepository(db: db, apiClient: apiClient),
      session: SessionController(
        db: db,
        apiClient: apiClient,
        tokenStore: tokenStore,
        deviceUuid: deviceUuid,
        app: AppConfig.app,
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
