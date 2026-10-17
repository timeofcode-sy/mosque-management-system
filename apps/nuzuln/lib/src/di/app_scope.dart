import 'package:flutter/widgets.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../config.dart';
import '../features/guardian/di/app_scope.dart' as guardian_surface;
import '../features/student/di/app_scope.dart' as student_surface;
import '../features/teacher/di/app_scope.dart' as teacher_surface;

/// اعتماديات التطبيق الموحَّد، مبنيّةً مرّةً عند الإقلاع.
///
/// **مخزنٌ واحد وعميلٌ واحد وجلسةٌ واحدة** تتقاسمها الأسطحُ الثلاثة، ولكلّ سطحٍ
/// اعتمادياتُه كما كانت في تطبيقه المنفصل — فتبقى شاشاتُه تقرأ `AppScope.of`
/// الخاصَّ به بلا تعديل. والأسطحُ كلُّها تُبنى هنا لأن بناءها رخيص؛ الذي يُشغَّل
/// حسب الدور هو دورةُ مزامنة الأستاذ وحدها ([NuzulApp]).
class NuzulDependencies {
  NuzulDependencies({
    required this.endpoint,
    required this.session,
    required this.teacher,
    required this.guardian,
    required this.student,
  });

  /// الخادمُ الذي يكلّمه هذا التثبيت — يُبدَّل من شاشة البدء ([ServerEndpoint]).
  final ServerEndpoint endpoint;

  /// السطحُ العامل فيها: [SessionController.app].
  final SessionController session;

  final teacher_surface.AppDependencies teacher;
  final guardian_surface.AppDependencies guardian;
  final student_surface.AppDependencies student;

  static Future<NuzulDependencies> create({
    AppDatabase? database,
    TokenStore? tokens,
    ApiClient? api,
    ServerEndpoint? endpoint,
    PushTokenReader? pushToken,
    DeviceDetailsReader? deviceDetails,
    String baseUrl = AppConfig.baseUrl,
  }) async {
    final db = database ?? AppDatabase();
    final tokenStore = tokens ?? TokenStore();

    // ثابتٌ مدى عمر التثبيت: هو مفتاح `sync_devices` لا `user_id`
    // ([API.md §1](../../../../../docs/API.md)).
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

    // الإشعاراتُ لولي الأمر وحده (`NotifyGuardians`)، فلا يُسأل غيرُه إذنَها: طالبٌ
    // يُسأل عن إذنٍ لا يصله به شيءٌ أقربُ إلى «رفض» يوم يحتاجه.
    late final SessionController session;
    final readPushToken = pushToken ?? guardian_surface.readPushToken;
    session = SessionController(
      db: db,
      apiClient: apiClient,
      tokenStore: tokenStore,
      deviceUuid: deviceUuid,
      surfaces: Surface.all,
      appLabel: AppConfig.label,
      pushToken: () async =>
          session.app == Surface.guardian ? readPushToken() : null,
      deviceDetails: deviceDetails,
    );

    // `sync/pull?app=teacher` — المحرّكُ للأستاذ وحده، فاسمُه ثابت.
    final syncEngine = SyncEngine(
      db: db,
      apiClient: apiClient,
      app: Surface.teacher,
      deviceUuid: deviceUuid,
    );
    final circles = CircleRepository(db: db, syncEngine: syncEngine);

    return NuzulDependencies(
      endpoint: server,
      session: session,
      teacher: teacher_surface.AppDependencies(
        db: db,
        tokenStore: tokenStore,
        endpoint: server,
        apiClient: apiClient,
        syncEngine: syncEngine,
        repository: circles,
        session: session,
        sync: SyncController(
          engine: syncEngine,
          session: session,
          // مسودّةُ الأستاذ تُنظَّف بعد كل دورةٍ تستقرّ — خطافٌ لا يعرفه المحرّك.
          onSettled: circles.clearSettledDrafts,
        ),
      ),
      guardian: guardian_surface.AppDependencies(
        db: db,
        tokenStore: tokenStore,
        endpoint: server,
        apiClient: apiClient,
        repository: GuardianRepository(db: db, apiClient: apiClient),
        session: session,
      ),
      student: student_surface.AppDependencies(
        db: db,
        tokenStore: tokenStore,
        endpoint: server,
        apiClient: apiClient,
        repository: StudentSelfRepository(db: db, apiClient: apiClient),
        session: session,
      ),
    );
  }
}

/// يوصل [NuzulDependencies] إلى ما فوق الأسطح — شاشةُ الدخول وحدها اليوم.
class NuzulScope extends InheritedWidget {
  const NuzulScope({super.key, required this.dependencies, required super.child});

  final NuzulDependencies dependencies;

  static NuzulDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NuzulScope>();
    assert(scope != null, 'NuzulScope غير موجود فوق هذه الشاشة.');

    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(NuzulScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
