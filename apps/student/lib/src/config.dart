/// إعدادات البناء — تُمرَّر بـ`--dart-define` ولا تُقرأ من ملفٍ في زمن التشغيل.
class AppConfig {
  const AppConfig._();

  /// الافتراضي `10.0.2.2` لا `127.0.0.1`: الأخيرُ داخل محاكي أندرويد هو المحاكي
  /// نفسه لا حاسوبُ المطوّر.
  static const String baseUrl = String.fromEnvironment(
    'MOUSQE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// يُرسَل في `POST /devices/register` — **ولا يُرسَل في `sync/pull?app=`**:
  /// الطالبُ لا يسحب التيّار أصلاً
  /// ([CHECKPOINT-PHASE-8.1.MD §2](../../../../docs/CHECKPOINT-PHASE-8.1.MD)).
  static const String app = 'student';

  static const String label = 'تطبيق الطالب';
}
