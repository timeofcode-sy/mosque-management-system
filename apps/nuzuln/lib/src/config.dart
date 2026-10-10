import 'package:mousqe_ui/mousqe_ui.dart';

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

  /// اسمُ التطبيق كما يظهر لصاحبه — على شاشة الدخول، وفي `device_name` الذي
  /// يقرؤه المشرف في `system/devices` (يتبعه السطحُ في حقل `app`).
  static const String label = 'نزلاً';

  /// اسمُ التطبيق على الهاتف — ويُكرَّر في `android:label` بـ AndroidManifest.xml
  /// (لا يقرؤه Dart).
  static const String launcherName = 'نزلاً';

  /// «حول التطبيق» — والنظامُ ومطوّرُه مشتركان في `mousqe_ui`.
  static const AboutAppInfo about = AboutAppInfo(
    title: launcherName,
    summary: 'تطبيقُ الهاتف للأستاذ ووليّ الأمر والطالب: دخولٌ واحد، '
        'ولكلٍّ شاشاتُه بحسب حسابه.',
  );
}

/// أسطحُ التطبيق، وكلٌّ منها **اسمُ دورٍ** على الخادم وقيمةُ `app` التي يُسجَّل
/// بها الجهاز — `NotifyGuardians` يرشّح بـ`app = guardian`، و`sync/pull?app=`
/// يقبل `teacher`.
///
/// والترتيبُ ترتيبُ عرضها على حسابٍ يحمل أكثر من دور.
abstract final class Surface {
  static const String teacher = 'teacher';
  static const String guardian = 'guardian';
  static const String student = 'student';

  static const List<String> all = [teacher, guardian, student];

  static String label(String surface) => switch (surface) {
        teacher => 'الأستاذ',
        guardian => 'ولي الأمر',
        student => 'الطالب',
        _ => surface,
      };
}
