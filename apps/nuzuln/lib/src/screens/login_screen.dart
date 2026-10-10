import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../di/app_scope.dart';

/// الدخولُ الواحد للأسطح الثلاثة — والاستمارةُ نفسُها في `mousqe_ui` ([LoginForm]).
///
/// السطحُ لا يُستنتج من بادئة اسم المستخدم: الخادمُ يردّ أدوارَ الحساب مع
/// التوكن، و[SessionController] يحسمه منها. وحسابٌ يحمل أكثرَ من دورٍ يُسأل هنا.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = NuzulScope.of(context).session;

    return Scaffold(
      body: SafeArea(
        child: LoginForm(
          title: AppConfig.label,
          subtitle: 'سجّل الدخول باسم المستخدم الذي زوّدك به المعهد',
          notice: session.notice,
          errorMessageBuilder: _messageFor,
          onSubmit: (username, password) => session.signIn(
            username: username,
            password: password,
            chooseSurface: (candidates) => _chooseSurface(context, candidates),
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: AboutLinks(app: AppConfig.about),
      ),
    );
  }

  static String _messageFor(Object failure) => switch (failure) {
        AccountNotForThisApp(:final message) => message,
        SurfaceChoiceCancelled(:final message) => message,
        _ => fieldMessageFor(failure),
      };

  static Future<String?> _chooseSurface(
    BuildContext context,
    List<String> candidates,
  ) {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('الدخول بصفة'),
        children: [
          for (final surface in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(surface),
              child: Text(Surface.label(surface)),
            ),
        ],
      ),
    );
  }
}
