import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/di/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // المخزن والتوكن ومعرّف الجهاز تُقرأ قبل أول إطار، فتفتح الشاشةُ الأولى على
  // حالةٍ محسومة بدل أن تومض بين «داخل» و«خارج».
  runApp(GuardianApp(dependencies: await AppDependencies.create()));
}
