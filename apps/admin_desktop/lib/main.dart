import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/di/app_scope.dart';
import 'src/window/desktop_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // المخزن والتوكن ومعرّف الجهاز تُقرأ قبل أول إطار، فتفتح الشاشةُ الأولى على
  // حالةٍ محسومة بدل أن تومض بين «داخل» و«خارج».
  final dependencies = await AppDependencies.create();

  // ثم النافذة: تُضبط وتُظهَر قبل `runApp` مباشرةً، فلا يرى المستخدمُ نافذةً
  // بحجم المحرّك الافتراضي تقفز إلى مقاسها المحفوظ.
  await DesktopWindow.restoreAndShow();

  runApp(AdminDesktopApp(dependencies: dependencies));
}
