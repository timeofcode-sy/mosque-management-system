import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../di/app_scope.dart';

/// الدخول باسم المستخدم — والاستمارةُ نفسُها في `mousqe_ui`، وهذه **رابعُ مرّة**
/// تُركَّب فيها بلا تعديل.
///
/// وحسابُ الطالب يولَّد تلقائياً مع سجلّه (`StudentObserver` ✅ م.4.7)، فبطاقتُه
/// تصله من المعهد ولا يسجّل هو بنفسه.
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
          icon: Icons.school_outlined,
          notice: session.notice,
          errorMessageBuilder: fieldMessageFor,
          onSubmit: (username, password) =>
              session.signIn(username: username, password: password),
        ),
      ),
    );
  }
}
