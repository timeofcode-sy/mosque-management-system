import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import 'src/app.dart';
import 'src/config.dart';
import 'src/di/app_scope.dart';
import 'src/window/desktop_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // المخزن والتوكن ومعرّف الجهاز تُقرأ قبل أول إطار، فتفتح الشاشةُ الأولى على
  // حالةٍ محسومة بدل أن تومض بين «داخل» و«خارج».
  final dependencies = await AppDependencies.create();

  // ثم النافذة: تُضبط وتُظهَر قبل `runApp` مباشرةً، فلا يرى المستخدمُ نافذةً
  // بحجم المحرّك الافتراضي تقفز إلى مقاسها المحفوظ. والهاتفُ بلا نافذةٍ تُدار
  // (`window_manager` حزمةُ سطح مكتب لا وصلةَ لها في أندرويد).
  if (!AppConfig.isPhone) {
    await DesktopWindow.restoreAndShow();
  }

  runApp(
    AdminDesktopApp(
      dependencies: dependencies,
      appearance: await _appearance(),
      updater: await _updater(dependencies),
    ),
  );
}

/// التحديثُ من داخل البرنامج: APK على الهاتف، ومجلّدُ ويندوز مضغوطاً على الحاسوب — يُستبدل
/// البرنامجُ ويعود وحده. يسأل الخادمَ الآن، فيكون الجوابُ غالباً قد وصل حين تنسحب شاشةُ البدء.
Future<AppUpdater> _updater(AppDependencies dependencies) async {
  final file = PreferencesFile('updates.json');
  final updater = AppUpdater(
    target: AppConfig.updateTarget,
    baseUrl: () => dependencies.endpoint.baseUrl,
    deviceUuid: () async => dependencies.session.deviceUuid,
    read: file.read,
    write: file.write,
    // قبل أن يُغلق ويندوز البرنامجَ ليستبدله: تتوقّف المزامنة وتُغلق القاعدة فلا يُقطع
    // طلبٌ في منتصفه ولا كتابة.
    beforeRestart: () async {
      dependencies.sync.stop();
      await dependencies.db.close();
    },
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
