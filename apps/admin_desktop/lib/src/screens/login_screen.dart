import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../di/app_scope.dart';

/// الدخول — والاستمارةُ نفسُها في `mousqe_ui` ([LoginForm])، وما هنا ربطُها
/// بجلسة هذا التطبيق.
///
/// ويسجّل الجهازُ نفسَه بـ`app=admin_desktop` داخل [SessionController.signIn]،
/// فيميّزه المشرفُ في `system/devices` عن هاتف الأستاذ، ويأخذ مؤشّرَ مزامنةٍ
/// مستقلّاً ولو كان الحسابُ واحداً.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;

    return Scaffold(
      body: LoginForm(
        icon: Icons.account_balance_outlined,
        title: AppConfig.label,
        subtitle: 'سجّل الدخول بحساب المشرف أو مدير المعهد',
        notice: session.notice,
        errorMessageBuilder: fieldMessageFor,
        onSubmit: (username, password) =>
            session.signIn(username: username, password: password),
      ),
    );
  }
}
