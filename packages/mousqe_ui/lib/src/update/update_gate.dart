import 'package:flutter/material.dart';

import '../brand/brand.dart';
import 'app_updater.dart';
import 'update_screen.dart';

/// يوصل [AppUpdater] إلى كل شاشة — يلفّ `MousqeApp` كلَّه لا الرئيسيّةَ وحدها، لأن الشاشات
/// المدفوعة إلى الملّاح (حول التطبيق) تُبنى تحت `MaterialApp` لا تحت `home`.
class AppUpdateScope extends InheritedWidget {
  const AppUpdateScope({
    super.key,
    required this.updater,
    this.appName = Brand.name,
    required super.child,
  });

  final AppUpdater updater;

  /// اسمُ التطبيق كما يقرؤه صاحبُه في شاشة التحديث: «نزلاً»، «نزلاً · الإدارة».
  final String appName;

  /// بلا اعتماد: القائمةُ تحتاج المحدِّثَ لا إعادةَ البناء مع كل نبضة تنزيل.
  static AppUpdateScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppUpdateScope>();

  @override
  bool updateShouldNotify(AppUpdateScope oldWidget) =>
      updater != oldWidget.updater || appName != oldWidget.appName;
}

/// يحرس التطبيقَ بالتحديث: إصدارٌ إلزاميّ يحلّ محلَّ التطبيق كلِّه حتى يُثبَّت، واختياريٌّ يُعرض
/// مرّةً فوقه — و«لاحقاً» يؤجّله يوماً. ويسأل الخادمَ ثانيةً كلما عاد التطبيقُ إلى الواجهة بعد
/// غيابٍ طويل، ويُكمل التثبيتَ حين يعود صاحبُه من إعداد الإذن.
///
/// يوضع تحت `MaterialApp` (ابنُ شاشة البدء): يحتاج ملّاحاً يدفع إليه الشاشة.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  AppUpdateScope? _scope;
  int? _offered;
  bool _blocked = false;

  AppUpdater? get _updater => _scope?.updater;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final scope = AppUpdateScope.read(context);

    if (scope?.updater != _updater) {
      _updater?.removeListener(_onUpdate);
      _scope = scope;
      _updater?.addListener(_onUpdate);
      _blocked = _updater?.blocksApp ?? false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onUpdate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updater?.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updater?.onResumed();
    }
  }

  void _onUpdate() {
    final updater = _updater;

    if (updater == null || !mounted) {
      return;
    }

    if (updater.blocksApp != _blocked) {
      // إلزاميٌّ وصل وفوق الرئيسيّة شاشاتٌ مفتوحة: تُطوى، فلا يبقى بابٌ خلفيٌّ إلى التطبيق.
      if (updater.blocksApp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(
              context,
              rootNavigator: true,
            ).popUntil((route) => route.isFirst);
          }
        });
      }

      setState(() => _blocked = updater.blocksApp);
      return;
    }

    final build = updater.info?.buildNumber;

    if (updater.shouldPrompt && build != _offered) {
      _offered = build;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          openUpdateScreen(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;

    if (_blocked && scope != null) {
      return UpdateScreen(
        updater: scope.updater,
        appName: scope.appName,
        dismissible: false,
      );
    }

    return widget.child;
  }
}
