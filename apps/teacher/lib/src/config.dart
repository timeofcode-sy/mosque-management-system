/// إعدادات البناء — تُمرَّر بـ`--dart-define` ولا تُقرأ من ملفٍ في زمن التشغيل.
class AppConfig {
  const AppConfig._();

  /// العنوان الأساسي للـ API ([API.md §1](../../../../docs/API.md)).
  ///
  /// الافتراضي `10.0.2.2` لا `127.0.0.1`: الأخيرُ داخل محاكي أندرويد هو المحاكي
  /// نفسه لا حاسوبُ المطوّر، والأول هو الاسمُ المستعار الذي يوجّهه إلى المضيف.
  static const String baseUrl = String.fromEnvironment(
    'MOUSQE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// يُرسَل في `POST /devices/register` وفي `GET /sync/pull?app=` — نفس القيمة
  /// في الاثنين، وهي ما يظهر في شاشة `system/devices` باللوحة.
  static const String app = 'teacher';

  /// اسمُ التطبيق كما يظهر لصاحبه — على شاشة الدخول، وفي `device_name` الذي
  /// يقرؤه المشرف في `system/devices`.
  static const String label = 'تطبيق الأستاذ';
}
