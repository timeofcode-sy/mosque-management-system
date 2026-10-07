import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import 'di/app_scope.dart';
import 'screens/children_screen.dart';
import 'screens/login_screen.dart';

/// جذر التطبيق: يعيد بناء الثيم كلّما تغيّرت لقطةُ المعهد، ويبدّل بين شاشة
/// الدخول والشاشة الرئيسية بحسب حالة الجلسة.
///
/// **وبلا `sync.start()`**: نظيرُه في تطبيق الأستاذ يشغّل دورةَ المزامنة عند
/// جهوز الجلسة ويوقفها عند الخروج، ولا دورةَ ههنا — القراءةُ تقع عند فتح كل
/// شاشة وعند السحب للتحديث
/// ([CHECKPOINT-PHASE-7.1.MD §2](../../../../docs/CHECKPOINT-PHASE-7.1.MD)).
class GuardianApp extends StatefulWidget {
  const GuardianApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends State<GuardianApp> {
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
        home: switch (_session.stage) {
          SessionStage.starting => const _Splash(),
          SessionStage.signedOut => const LoginScreen(),
          SessionStage.ready => const ChildrenScreen(),
        },
      ),
    );
  }

  /// ثيمُ المعهد الثلاثي، أو لوحة `design-tokens.json` لمعهدٍ لم تصل لقطتُه بعد.
  ThemeData get _theme {
    final theme = _session.snapshot?.institute.theme;

    return MousqeTheme.fromHexes(
      primary: theme?.primary,
      secondary: theme?.secondary,
      surface: theme?.surface,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
