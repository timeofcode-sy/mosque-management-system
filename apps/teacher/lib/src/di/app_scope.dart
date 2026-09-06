import 'package:flutter/widgets.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../config.dart';
import '../data/teacher_repository.dart';
import '../state/session_controller.dart';
import '../state/sync_controller.dart';

/// اعتماديات التطبيق، مبنيّةً مرّةً عند الإقلاع.
///
/// بلا حزمة حقن اعتماديات: الرسمُ البياني هنا ستة كائنات تُبنى بترتيبٍ واحد
/// ممكن، و`InheritedWidget` يوصلها إلى الشجرة بلا طبقةٍ ثالثة تُتعلَّم.
class AppDependencies {
  AppDependencies({
    required this.db,
    required this.tokenStore,
    required this.apiClient,
    required this.syncEngine,
    required this.repository,
    required this.session,
    required this.sync,
  });

  final AppDatabase db;
  final TokenStore tokenStore;
  final ApiClient apiClient;
  final SyncEngine syncEngine;
  final TeacherRepository repository;
  final SessionController session;
  final SyncController sync;

  static Future<AppDependencies> create({
    AppDatabase? database,
    TokenStore? tokens,
    String baseUrl = AppConfig.baseUrl,
  }) async {
    final db = database ?? AppDatabase();
    final tokenStore = tokens ?? TokenStore();

    // ثابتٌ مدى عمر التثبيت: هو مفتاح `sync_devices` لا `user_id`، فللمستخدم أن
    // يعمل من هاتفه وحاسوب الحلقة بمؤشّرين ([API.md §1](../../../../../docs/API.md)).
    final deviceUuid = await tokenStore.deviceUuid();

    final apiClient = ApiClient.create(
      tokenStore: tokenStore,
      baseUrl: baseUrl,
    );
    final syncEngine = SyncEngine(
      db: db,
      apiClient: apiClient,
      app: AppConfig.app,
      deviceUuid: deviceUuid,
    );

    final repository = TeacherRepository(db: db, syncEngine: syncEngine);
    final session = SessionController(
      db: db,
      apiClient: apiClient,
      tokenStore: tokenStore,
      deviceUuid: deviceUuid,
    );

    return AppDependencies(
      db: db,
      tokenStore: tokenStore,
      apiClient: apiClient,
      syncEngine: syncEngine,
      repository: repository,
      session: session,
      sync: SyncController(
        engine: syncEngine,
        repository: repository,
        session: session,
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
