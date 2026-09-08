import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import 'di/app_scope.dart';
import 'screens/login_screen.dart';
import 'shell/desktop_shell.dart';

/// جذر التطبيق: يعيد بناء الثيم كلّما تغيّرت لقطةُ المعهد، ويبدّل بين شاشة
/// الدخول والهيكل بحسب حالة الجلسة.
class AdminDesktopApp extends StatefulWidget {
  const AdminDesktopApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<AdminDesktopApp> createState() => _AdminDesktopAppState();
}

class _AdminDesktopAppState extends State<AdminDesktopApp> {
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

  void _onSessionChanged() {
    if (_session.stage == SessionStage.ready) {
      widget.dependencies.sync.start();

      // قائمةُ المعاهد تُجلب مرّةً عند الجهوز لا في كل بناء: بها وحدها يُعرف هل
      // يظهر المبدّل أصلاً، وهي طلبُ شبكةٍ لا يصحّ أن يتكرّر مع كل إطار.
      if (widget.dependencies.institutes.options.isEmpty) {
        widget.dependencies.institutes.load();
      }
    } else {
      widget.dependencies.sync.stop();
      widget.dependencies.institutes.clear();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: widget.dependencies,
      child: MousqeApp(
        theme: _theme,
        home: switch (_session.stage) {
          SessionStage.starting => const _Splash(),
          SessionStage.signedOut => const LoginScreen(),
          SessionStage.ready => const DesktopShell(),
        },
      ),
    );
  }

  /// ثيمُ المعهد الثلاثي بمقاسات المكتب — نفسُ هوية اللوحة وتطبيقِ الأستاذ،
  /// فلا يبدو البرنامجان من بيتين.
  ThemeData get _theme {
    final theme = _session.snapshot?.institute.theme;

    return MousqeTheme.forDesktop(
      MousqeTheme.fromHexes(
        primary: theme?.primary,
        secondary: theme?.secondary,
        surface: theme?.surface,
      ),
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
