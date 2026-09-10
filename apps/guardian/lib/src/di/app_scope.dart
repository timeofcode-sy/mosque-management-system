import 'package:flutter/widgets.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../config.dart';

/// اعتماديات التطبيق، مبنيّةً مرّةً عند الإقلاع.
///
/// **وهي خمسةٌ لا سبعة**: لا `SyncEngine` ولا `SyncController` ههنا. وليُّ الأمر
/// خارجَ `sync/pull` كلِّه، وكتابتُه الوحيدة (تقديمُ الإذن) متّصلةٌ بطبعها فلا
/// طابورَ لها ([CHECKPOINT-PHASE-7.1.MD §2](../../../../../docs/CHECKPOINT-PHASE-7.1.MD)).
///
/// و[SessionController] يُعاد استخدامُه **كما هو**: ما يختلف بين الأسطح معاملان
/// ([app] و[appLabel])، وقد بُني على ذلك في م.6.3 حين احتاجه الديسكتوب.
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
  final GuardianRepository repository;
  final SessionController session;

  static Future<AppDependencies> create({
    AppDatabase? database,
    TokenStore? tokens,
    ApiClient? api,
    String baseUrl = AppConfig.baseUrl,
  }) async {
    final db = database ?? AppDatabase();
    final tokenStore = tokens ?? TokenStore();

    // ثابتٌ مدى عمر التثبيت: هو مفتاح `sync_devices` لا `user_id`، فلوليّ الأمر
    // أن يتابع من هاتفه ومن هاتف زوجه بمؤشّرين
    // ([API.md §1](../../../../../docs/API.md)).
    final deviceUuid = await tokenStore.deviceUuid();

    final apiClient = api ?? ApiClient.create(tokenStore: tokenStore, baseUrl: baseUrl);

    return AppDependencies(
      db: db,
      tokenStore: tokenStore,
      apiClient: apiClient,
      repository: GuardianRepository(db: db, apiClient: apiClient),
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
