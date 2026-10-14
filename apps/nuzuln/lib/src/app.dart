import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import 'config.dart';
import 'di/app_scope.dart';
import 'features/guardian/di/app_scope.dart' as guardian;
import 'features/guardian/screens/children_screen.dart';
import 'features/student/di/app_scope.dart' as student;
import 'features/student/screens/home_screen.dart';
import 'features/teacher/di/app_scope.dart' as teacher;
import 'features/teacher/screens/circles_screen.dart';
import 'screens/login_screen.dart';

/// جذر التطبيق: يبدّل بين شاشة الدخول ورئيسيّةِ السطح الذي حسمه الدخول.
///
/// نطاقاتُ الأسطح الثلاثة تلفّ [MousqeApp] كلَّه لا الرئيسيّةَ وحدها: الشاشاتُ
/// المدفوعة إلى الملّاح تُبنى تحت `MaterialApp` لا تحت `home`، فلو لُفّت الرئيسيّةُ
/// وحدها لَما وجدت شاشةٌ مدفوعةٌ نطاقَها.
class NuzulApp extends StatefulWidget {
  const NuzulApp({
    super.key,
    required this.dependencies,
    this.appearance,
    this.updater,
  });

  final NuzulDependencies dependencies;

  /// الوضعُ وحجمُ الخط كما اختارهما صاحبُ الجهاز — `null` في الاختبارات.
  final AppearanceController? appearance;

  /// التحديثُ من داخل التطبيق — `null` في الاختبارات.
  final AppUpdater? updater;

  @override
  State<NuzulApp> createState() => _NuzulAppState();
}

class _NuzulAppState extends State<NuzulApp> {
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

  /// دورةُ المزامنة للأستاذ وحده: وليُّ الأمر والطالب خارجَ `sync/pull` كلِّه،
  /// يقرآن عند فتح كل شاشة ([CHECKPOINT-PHASE-7.1.MD §2](../../../../docs/checkpoints/CHECKPOINT-PHASE-7.1.MD)).
  void _onSessionChanged() {
    final sync = widget.dependencies.teacher.sync;

    if (_session.stage == SessionStage.ready && _session.app == Surface.teacher) {
      sync.start();
    } else {
      sync.stop();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;

    final app = MousqeApp(
      title: AppConfig.launcherName,
      theme: MousqeTheme.light(),
      darkTheme: MousqeTheme.dark(),
      appearance: widget.appearance,
      home: SplashGate(
        ready: _session.stage != SessionStage.starting,
        caption: AppConfig.label,
        onServerChoice: (context) =>
            showServerChoiceDialog(context, _serverChoice),
        // التحديثُ يحرس الدخولَ أيضاً: إصدارٌ إلزاميّ لا ينتظر حساباً.
        child: UpdateGate(
          child: switch (_session.stage) {
            // تحت شاشة البدء لا يُبنى شيء: تغطّيه حتى تُحسم الجلسة.
            SessionStage.starting => const SizedBox.shrink(),
            SessionStage.signedOut => const LoginScreen(),
            SessionStage.ready => _home(_session.app),
          },
        ),
      ),
    );
    final updater = widget.updater;

    return NuzulScope(
      dependencies: deps,
      child: teacher.AppScope(
        dependencies: deps.teacher,
        child: guardian.AppScope(
          dependencies: deps.guardian,
          child: student.AppScope(
            dependencies: deps.student,
            child: updater == null
                ? app
                : AppUpdateScope(
                    updater: updater,
                    appName: AppConfig.launcherName,
                    child: app,
                  ),
          ),
        ),
      ),
    );
  }

  /// `KeyedSubtree` بالسطح: خروجُ الأب ودخولُ الابن على الهاتف نفسه لا يُبقي
  /// حالةَ شاشةٍ من سطحٍ إلى سطح.
  Widget _home(String? surface) => KeyedSubtree(
        key: ValueKey(surface),
        child: switch (surface) {
          Surface.teacher => const CirclesScreen(),
          Surface.guardian => const ChildrenScreen(),
          Surface.student => const HomeScreen(),
          // الجلسةُ لا تبلغ `ready` بلا سطح؛ فرعٌ للمحلّل لا للمستخدم.
          _ => const LoginScreen(),
        },
      );

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
}
