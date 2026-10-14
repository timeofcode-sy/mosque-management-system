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
    ),
  );
}

/// مظهرُ صاحب الجهاز محفوظاً في ملفٍّ على الجهاز — يُقرأ قبل أول إطار فلا يومض الوضعُ.
Future<AppearanceController> _appearance() async {
  final file = PreferencesFile('appearance.json');
  final appearance = AppearanceController(read: file.read, write: file.write);
  await appearance.load();

  return appearance;
}
