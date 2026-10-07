import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import 'config.dart';
import 'di/app_scope.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// جذر التطبيق: يعيد بناء الثيم كلّما تغيّرت لقطةُ المعهد، ويبدّل بين شاشة
/// الدخول والرئيسية بحسب حالة الجلسة. **وبلا `sync.start()`** — لا دورةَ مزامنة
/// في هذا التطبيق.
class StudentApp extends StatefulWidget {
  const StudentApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  SessionController get _session => widget.dependencies.session;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _session.restore();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: widget.dependencies,
      child: MousqeApp(
        theme: _theme,
        home: SplashGate(
          ready: _session.stage != SessionStage.starting,
          caption: AppConfig.label,
          onServerChoice: (context) =>
              showServerChoiceDialog(context, _serverChoice),
          child: switch (_session.stage) {
            // تحت شاشة البدء لا يُبنى شيء: تغطّيه حتى تُحسم الجلسة.
            SessionStage.starting => const SizedBox.shrink(),
            SessionStage.signedOut => const LoginScreen(),
            SessionStage.ready => const HomeScreen(),
          },
        ),
      ),
    );
  }

  /// ثلاثُ نقراتٍ على شعار شاشة البدء: الخادمُ الرئيسي أو خادمٌ محلّي.
  ServerChoice get _serverChoice {
    final endpoint = widget.dependencies.endpoint;

    return ServerChoice(
      primaryHost: ServerEndpoint.primaryHost,
      usesPrimary: endpoint.usesPrimary,
      localAddress: endpoint.localAddress,
      warning: _session.stage == SessionStage.ready
          ? 'تبديلُ الخادم يُخرجك من حسابك ويمسح بياناتِ هذا الجهاز المحلية.'
          : null,
      validateLocal: ServerEndpoint.validateLocal,
      check: (primary, local) => endpoint.probe(primary: primary, local: local),
      apply: (primary, local) => endpoint.choose(
        primary: primary,
        local: local,
        session: _session,
      ),
    );
  }

  ThemeData get _theme {
    final theme = _session.snapshot?.institute.theme;

    return MousqeTheme.fromHexes(
      primary: theme?.primary,
      secondary: theme?.secondary,
      surface: theme?.surface,
    );
  }
}
