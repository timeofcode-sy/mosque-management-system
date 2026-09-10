import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/di/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(StudentApp(dependencies: await AppDependencies.create()));
}
