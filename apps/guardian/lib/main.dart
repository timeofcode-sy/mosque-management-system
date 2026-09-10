import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/di/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initialiseFirebase();

  // المخزن والتوكن ومعرّف الجهاز تُقرأ قبل أول إطار، فتفتح الشاشةُ الأولى على
  // حالةٍ محسومة بدل أن تومض بين «داخل» و«خارج».
  runApp(GuardianApp(dependencies: await AppDependencies.create()));
}

/// تهيئةُ Firebase — ✅ م.7.4، **ولا تُسقط التطبيق إن فشلت**.
///
/// 🔑 وهذا هو القرارُ الذي يستحقّ الكتابة: الشائعُ أن تُكتب
/// `await Firebase.initializeApp(...)` عاريةً في `main`، فيصير **الإشعارُ شرطاً
/// لإقلاع التطبيق**. وليس كذلك: وليُّ الأمر يفتح التطبيقَ ليقرأ حضورَ ابنه، وذاك
/// يعمل بلا Firebase أصلاً (م.7.1–7.3). ولو رُميت هنا لَما فتح التطبيقُ في جهازٍ
/// بلا Google Play Services، ولا في جهازٍ رُكّب عليه بناءٌ بلا `google-services.json`.
///
/// فالفشلُ يُبتلع **ههنا وحده**: [SessionController] لا يمرّر توكناً حينئذ، وسطحُ
/// الخادم يقبل التسجيلَ بلا الحقل منذ م.4 — فتنقص **الفوريةُ لا الوظيفة**، وهي
/// القاعدةُ نفسُها التي بُنيت عليها المرحلة كلُّها
/// ([PHASE-7-STAGES.MD §0.2](../../../docs/PHASE-7-STAGES.MD)).
Future<void> _initialiseFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error, stack) {
    debugPrint('تعذّرت تهيئة Firebase — يعمل التطبيق بلا إشعارات: $error');
    debugPrintStack(stackTrace: stack);
  }
}
