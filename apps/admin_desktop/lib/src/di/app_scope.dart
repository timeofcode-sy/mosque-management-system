import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../state/institute_switcher.dart';

/// اعتماديات التطبيق، مبنيّةً مرّةً عند الإقلاع.
///
/// بلا حزمة حقن اعتماديات — نفسُ قرار تطبيق الأستاذ: الرسمُ البياني هنا سبعة
/// كائنات تُبنى بترتيبٍ واحد ممكن، و`InheritedWidget` يوصلها إلى الشجرة.
class AppDependencies {
  AppDependencies({
    required this.db,
    required this.tokenStore,
    required this.apiClient,
    required this.syncEngine,
    required this.session,
    required this.sync,
    required this.institutes,
  });

  final AppDatabase db;
  final TokenStore tokenStore;
  final ApiClient apiClient;
  final SyncEngine syncEngine;
  final SessionController session;
  final SyncController sync;
  final InstituteSwitcher institutes;

  static Future<AppDependencies> create({
    AppDatabase? database,
    TokenStore? tokens,
    String baseUrl = AppConfig.baseUrl,
  }) async {
    final db = database ?? AppDatabase(_openStore());
    final tokenStore = tokens ?? TokenStore();

    // ثابتٌ مدى عمر التثبيت: هو مفتاح `sync_devices` لا `user_id`، فللمستخدم أن
    // يعمل من مكتبه وحاسوب الحلقة بمؤشّرين ([API.md §1](../../../../../docs/API.md)).
    final deviceUuid = await tokenStore.deviceUuid();

    // يُبنى قبل العميل ويُقرأ منه في كل طلب: هو ما يكسر دورةَ الاعتماد بين
    // `ApiClient` و`SessionController` — [ActiveInstitute].
    final activeInstitute = ActiveInstitute();

    final apiClient = ApiClient.create(
      tokenStore: tokenStore,
      baseUrl: baseUrl,
      instituteUuid: () => activeInstitute.uuid,
    );
    final syncEngine = SyncEngine(
      db: db,
      apiClient: apiClient,
      app: AppConfig.app,
      deviceUuid: deviceUuid,
    );
    final session = SessionController(
      db: db,
      apiClient: apiClient,
      tokenStore: tokenStore,
      deviceUuid: deviceUuid,
      app: AppConfig.app,
      appLabel: AppConfig.label,
      activeInstitute: activeInstitute,
    );

    final sync = SyncController(
      engine: syncEngine,
      session: session,
      // أقصرُ من دورة الأستاذ: هذا جهازُ مكتبٍ موصولٌ بالكهرباء، وصاحبُه يكتب
      // ما يقرؤه أستاذٌ في الحلقة بعد قليل.
      interval: const Duration(minutes: 1),
    );

    return AppDependencies(
      db: db,
      tokenStore: tokenStore,
      apiClient: apiClient,
      syncEngine: syncEngine,
      session: session,
      sync: sync,
      institutes: InstituteSwitcher(session: session, sync: sync),
    );
  }

  /// ملفُّ drift في مجلّد بيانات التطبيق لا في «المستندات».
  ///
  /// افتراضيُّ الحزمة `getApplicationDocumentsDirectory` — وهو على ويندوز مجلّدُ
  /// «المستندات» الذي يفتحه المستخدم كل يوم، فلا يليق أن يجد فيه ملفَّ قاعدةٍ
  /// لا يعنيه. واسمُه يميّزه عن ملفّ تطبيق الأستاذ، فيتعايش التطبيقان على جهازٍ
  /// واحد بمخزنين ومؤشّرَي مزامنة.
  static QueryExecutor _openStore() {
    return LazyDatabase(() async {
      final directory = await getApplicationSupportDirectory();

      return NativeDatabase.createInBackground(
        File(p.join(directory.path, 'mousqe_admin.sqlite')),
      );
    });
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
