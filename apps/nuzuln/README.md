# نزلاً — تطبيق الهاتف

الأستاذ ووليّ الأمر والطالب في تطبيقٍ واحد (`com.timeofcode.nuzuln`). الإدارة تبقى في `apps/admin_desktop`.

## كيف يُحسم السطح

- الدخولُ واحد. الخادمُ يردّ أدوارَ الحساب مع التوكن (`POST /auth/login`)، و`SessionController` في `mousqe_core` يختار منها `teacher` أو `guardian` أو `student`. لا يُعتمد على بادئة اسم المستخدم.
- حسابٌ يحمل أكثرَ من دور يُسأل «الدخول بصفة…».
- حسابٌ بلا أيّ من الأدوار الثلاثة (مشرف، مدير) يُردّ إلى تطبيق الإدارة ويُبطَل توكنُه.
- السطحُ يُحفظ في `app_state` ويُمسح عند الخروج، فالهاتفُ العائلي لا يورّث سطحَ الأب للابن.
- قيمةُ `app` في `POST /devices/register` هي السطح نفسه، فلا تغيير في الخادم.

## البنية

```text
lib/src/
  app.dart              NuzulApp — يوجّه حسب السطح، ويشغّل مزامنة الأستاذ وحده
  di/app_scope.dart     NuzulDependencies — مخزنٌ وعميلٌ وجلسةٌ مشتركة
  screens/login_screen.dart
  features/{teacher,guardian,student}/   شاشاتُ كلّ سطحٍ كما كانت في تطبيقه المنفصل
```

## ⚠️ الإشعارات (Firebase)

`google-services.json` غير موجود بعد: الملفُّ الحالي في `apps/guardian` مسجَّلٌ لـ`sy.mousqe.mousqe_guardian`.
حتى يُضاف، يُبنى التطبيقُ ويعمل كاملاً **بلا إشعارات**. للتفعيل:

1. أضِف تطبيق أندرويد `com.timeofcode.nuzuln` في مشروع Firebase `mousqe`.
2. من `apps/nuzuln` شغّل `flutterfire configure`، فيكتب `android/app/google-services.json` ويجدّد `lib/firebase_options.dart`.

ملحقُ `google-services` في Gradle يُطبَّق تلقائياً متى وُجد الملف.

ما بقي لاكتمال التطبيق خطوةً خطوة: [NEXT-STEPS.md](NEXT-STEPS.md).
