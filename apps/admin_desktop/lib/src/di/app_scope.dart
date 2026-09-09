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
    required this.circles,
    required this.students,
    required this.catalog,
    required this.admin,
    required this.stats,
    required this.conflicts,
  });

  final AppDatabase db;
  final TokenStore tokenStore;
  final ApiClient apiClient;
  final SyncEngine syncEngine;
  final SessionController session;
  final SyncController sync;
  final InstituteSwitcher institutes;

  /// عملُ الحلقة كلُّه — مرفوعٌ إلى `mousqe_core` في م.6.4 ومشتركٌ مع الأستاذ.
  final CircleRepository circles;

  /// ✅ م.6.5 — والثلاثةُ منفصلةٌ بقناة الكتابة لا بالموضوع:
  ///
  /// | | يقرأ | يكتب | أوف-لاين |
  /// |---|---|---|---|
  /// | [students] | drift | الطابور | ✓ |
  /// | [catalog] | drift | REST | ✗ الكتابةُ وحدها |
  /// | [admin] | الشبكة | REST | ✗ |
  ///
  /// وهي القاعدةُ المُعلَنة في [PHASE-6-STAGES.MD §3.1] مرسومةً في الاعتماديات:
  /// ما يُكتب في المسجد بلا شبكة يمرّ بالطابور، وما هو متّصلٌ بطبعه REST.
  final StudentRepository students;

  final CatalogRepository catalog;

  final AdminRepository admin;

  /// ✅ م.6.6 — والقناتان الأخيرتان في جدول القراءة والكتابة:
  ///
  /// | | يقرأ | يكتب | أوف-لاين |
  /// |---|---|---|---|
  /// | [stats] | drift | **لا يكتب** | ✓ |
  /// | [conflicts] | الشبكة | REST | ✗ |
  ///
  /// و[stats] كائنُ قراءةٍ صرف: الإحصاءُ **مشتقٌّ يُحسب** لا صفٌّ يُنقَل
  /// ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md))، فليس له ما
  /// يكتبه أصلاً. و[conflicts] نظيرُ [admin] في أنه لا مخزنَ له: `sync_conflicts`
  /// جدولٌ لا يُزامَن، فما لا يصل في `sync/pull` يُقرأ من الشبكة.
  final StatsRepository stats;

  final ConflictRepository conflicts;

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

    final circles = CircleRepository(db: db, syncEngine: syncEngine);
    final students = StudentRepository(db: db, syncEngine: syncEngine);

    final sync = SyncController(
      engine: syncEngine,
      session: session,
      // أقصرُ من دورة الأستاذ: هذا جهازُ مكتبٍ موصولٌ بالكهرباء، وصاحبُه يكتب
      // ما يقرؤه أستاذٌ في الحلقة بعد قليل.
      interval: const Duration(minutes: 1),
      // نظيرُ خطّاف الأستاذ: مسودّةٌ استقرّ طابورُها لم يعد لها معنى، وبقاؤها
      // يعني عرضَ قيمةٍ محلية فوق قيمةٍ حسمها الخادم بخلافها.
      onSettled: circles.clearSettledDrafts,
    );

    return AppDependencies(
      db: db,
      tokenStore: tokenStore,
      apiClient: apiClient,
      syncEngine: syncEngine,
      session: session,
      sync: sync,
      institutes: InstituteSwitcher(session: session, sync: sync),
      circles: circles,
      students: students,
      catalog: CatalogRepository(db: db, apiClient: apiClient),
      admin: AdminRepository(apiClient: apiClient),
      stats: StatsRepository(db: db),
      conflicts: ConflictRepository(apiClient: apiClient),
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
