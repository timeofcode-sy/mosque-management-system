import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../di/app_scope.dart';

/// الدخول باسم المستخدم لا بالبريد — والاستمارةُ نفسُها في `mousqe_ui`
/// ([LoginForm])، وما هنا هو ربطُها بجلسة هذا التطبيق.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;

    return Scaffold(
      body: SafeArea(
        child: LoginForm(
          title: AppConfig.label,
          subtitle: 'سجّل الدخول باسم المستخدم الذي زوّدك به المعهد',
          notice: session.notice,
          errorMessageBuilder: fieldMessageFor,
          onSubmit: (username, password) =>
              session.signIn(username: username, password: password),
        ),
      ),
    );
  }
}
