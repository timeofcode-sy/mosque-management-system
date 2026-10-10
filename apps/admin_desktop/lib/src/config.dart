import 'package:flutter/foundation.dart';

/// إعدادات البناء — تُمرَّر بـ`--dart-define` ولا تُقرأ من ملفٍ في زمن التشغيل.
class AppConfig {
  const AppConfig._();

  /// العنوان الأساسي للـ API ([API.md §1](../../../../../docs/API.md)).
  ///
  /// `127.0.0.1` لا `10.0.2.2` كتطبيق الأستاذ: هذا البرنامج يعمل على الحاسوب
  /// نفسه لا داخل محاكي أندرويد، فالمضيفُ المحلي هو المضيفُ المحلي. ونسخةُ
  /// الهاتف تُبنى بعنوان الخادم الرئيسي، ويُبدَّل من شاشة البدء.
  static const String baseUrl = String.fromEnvironment(
    'MOUSQE_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// نسخةُ الهاتف (أندرويد): البرنامجُ نفسُه بهيكلٍ آخر — شريطٌ سفلي لا قائمةٌ
  /// جانبية، ولا نافذةَ تُدار.
  static bool get isPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// يُرسَل في `POST /devices/register` وفي `GET /sync/pull?app=` — نفس القيمة
  /// في الاثنين، وهي ما يظهر في شاشة `system/devices` باللوحة.
  ///
  /// جهازٌ واحد قد يحمل التطبيقين، ولكلٍّ `device_uuid` ومؤشّرُ مزامنةٍ مستقلّ.
  /// والهاتفُ يُسجَّل `admin_mobile` فيميّزه المشرفُ عن حاسوب المكتب.
  static String get app => isPhone ? 'admin_mobile' : 'admin_desktop';

  /// اسمُ التطبيق كما يظهر لصاحبه — على شاشة الدخول، وفي عنوان النافذة، وفي
  /// `device_name` الذي يقرؤه المشرف في `system/devices`.
  static const String label = 'إدارة المعهد';

  /// اسمُ التطبيق على الهاتف (أيقونةُ المشغّل وقائمةُ التطبيقات الأخيرة)، كأسماء
  /// التطبيقات الثلاثة الأخرى. ويُكرَّر في `android:label` بـ AndroidManifest.xml.
  static const String launcherName = 'نزلاً · الإدارة';
}
