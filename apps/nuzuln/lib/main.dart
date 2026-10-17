import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/config.dart';
import 'src/di/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initialiseFirebase();

  // المخزن والتوكن ومعرّف الجهاز تُقرأ قبل أول إطار، فتفتح الشاشةُ الأولى على
  // حالةٍ محسومة بدل أن تومض بين «داخل» و«خارج».
  final dependencies = await NuzulDependencies.create();

  runApp(
    NuzulApp(
      dependencies: dependencies,
      appearance: await _appearance(),
      updater: await _updater(dependencies),
    ),
  );
}

/// التحديثُ من داخل التطبيق: يسأل الخادمَ الآن، فيكون الجوابُ غالباً قد وصل حين تنسحب شاشةُ
/// البدء — وإصدارٌ إلزاميّ يظهر مكانَ التطبيق من أول نظرة.
Future<AppUpdater> _updater(NuzulDependencies dependencies) async {
  final file = PreferencesFile('updates.json');
  final updater = AppUpdater(
    target: AppConfig.updateTarget,
    baseUrl: () => dependencies.endpoint.baseUrl,
    deviceUuid: () async => dependencies.session.deviceUuid,
    read: file.read,
    write: file.write,
  );
  await updater.load();
  unawaited(updater.check());

  return updater;
}

/// مظهرُ صاحب الجهاز محفوظاً في ملفٍّ على الجهاز — يُقرأ قبل أول إطار فلا يومض الوضعُ.
Future<AppearanceController> _appearance() async {
  final file = PreferencesFile('appearance.json');
  final appearance = AppearanceController(read: file.read, write: file.write);
  await appearance.load();

  return appearance;
}

/// تهيئةُ Firebase — **ولا تُسقط التطبيق إن فشلت**.
///
/// الإشعارُ ميزةٌ فوق الوظيفة لا شرطٌ لها: جهازٌ بلا Google Play Services، أو
/// بناءٌ بلا `google-services.json` مسجَّلٍ لـ`com.timeofcode.nuzuln`، يعمل كاملاً بلا
/// إشعارات — [SessionController] لا يمرّر توكناً حينئذ
/// ([PHASE-7-STAGES.MD §0.2](../../../docs/phases/PHASE-7-STAGES.MD)).
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
