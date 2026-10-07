import 'package:firebase_messaging/firebase_messaging.dart';
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
    PushTokenReader? pushToken,
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
        pushToken: pushToken ?? readPushToken,
      ),
    );
  }
}

/// توكنُ الإشعارات لهذا الجهاز — ✅ م.7.4.
///
/// يُستدعى **مرّةً عند الدخول** فيركب مع `POST /devices/register`
/// ([CHECKPOINT-PHASE-7.4.MD §5](../../../../docs/CHECKPOINT-PHASE-7.4.MD)).
///
/// ## 🔑 والإذنُ يُطلب هنا لا عند الإقلاع
///
/// أندرويد 13+ يتطلّب `POST_NOTIFICATIONS` صراحةً. وطلبُه على شاشة الدخول —
/// **قبل أن يعرف المستخدمُ ما التطبيق أصلاً** — أسرعُ طريقٍ إلى «رفض»: نافذةٌ
/// تقفز على غريبٍ يُسأل عن إذنٍ لا يعرف فيمَ يُستعمل. وحين يقع الطلبُ بعد أن
/// يدخل بحسابه، يكون قد عرف أن التطبيق تطبيقُ متابعةِ ابنه.
///
/// **ورفضُه لا يعني شيئاً سيّئاً**: تعود `null`، ويسجَّل الجهازُ بلا الحقل،
/// ويعمل التطبيقُ كاملاً — القراءةُ لا تحتاج إشعاراً.
///
/// وترمي حين تكون Firebase غير مهيَّأة (جهازٌ بلا Google Play Services مثلاً)،
/// و[SessionController] يبتلع ذلك بنفسه فلا يُسقط الدخول.
Future<String?> readPushToken() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission();

  // `provisional` إذنٌ مؤقّت تمنحه iOS بلا سؤالٍ صريح — والإشعاراتُ تصل تحته،
  // فلا يُعامَل معاملةَ الرفض.
  final granted = {
    AuthorizationStatus.authorized,
    AuthorizationStatus.provisional,
  };

  if (! granted.contains(settings.authorizationStatus)) {
    return null;
  }

  return messaging.getToken();
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
