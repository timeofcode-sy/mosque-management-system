import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import 'config.dart';
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
        title: AppConfig.isPhone ? AppConfig.launcherName : Brand.name,
        theme: adaptTheme(MousqeTheme.light()),
        darkTheme: adaptTheme(MousqeTheme.dark()),
        home: SplashGate(
          ready: _session.stage != SessionStage.starting,
          caption: AppConfig.label,
          onServerChoice: (context) =>
              showServerChoiceDialog(context, _serverChoice),
          child: switch (_session.stage) {
            // تحت شاشة البدء لا يُبنى شيء: تغطّيه حتى تُحسم الجلسة.
            SessionStage.starting => const SizedBox.shrink(),
            SessionStage.signedOut => const LoginScreen(),
            SessionStage.ready => const DesktopShell(),
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
      apply: (primary, local) =>
          endpoint.choose(primary: primary, local: local, session: _session),
    );
  }
}

/// ما يزيده هذا التطبيقُ على ثيم الحزمة للّمس (الهاتف): الزرُّ العائم، والحوارُ يأخذ عرضَ الشاشة
/// إلا 16px من كل جانب — هامشُ الصفحة نفسُه — بدل 40px تأكل ربعَ هاتفٍ بعرض 360.
/// ونسخةُ المكتب تبقى على ثيمها كما هو.
ThemeData adaptTheme(ThemeData theme) {
  if (theme.visualDensity == VisualDensity.compact) {
    return theme;
  }

  final c = theme.extension<NzPalette>()!.tokens;

  return theme.copyWith(
    // الزرُّ العائم بهوية الأزرار المصمتة: أخضرُ عميق (نحاسٌ ليلاً) بزاوية 3px،
    // مسطّحٌ كسائر الأسطح — لا ظلَّ Material الثقيل ولا كبسولة.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      elevation: 1,
      focusElevation: 1,
      hoverElevation: 2,
      highlightElevation: 2,
      extendedTextStyle: NzType.label.copyWith(fontSize: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NzRadius.sm),
      ),
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: NzSpace.s4,
        vertical: NzSpace.s5,
      ),
    ),
  );
}
