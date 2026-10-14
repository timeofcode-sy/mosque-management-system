import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

import '../widgets/home_hadith.dart';
import 'brand.dart';

/// شاشةُ البدء: العلامةُ وسطَ الأرضية الخضراء، بنفس لونِ شاشة أندرويد الأصلية
/// ومقاسِها (128dp) — فتنتقل هذه من تلك دون أن يلحظ المستخدمُ أنهما شاشتان.
class BrandSplash extends StatelessWidget {
  const BrandSplash({
    super.key,
    this.caption,
    this.onLogoTap,
    this.showHadith = true,
  });

  /// اسمُ التطبيق أسفلَ الشاشة — «تطبيق الأستاذ»، «إدارة المعهد».
  final String? caption;

  /// نقرةٌ على الشعار — لا يعرف هذا الودجت لماذا؛ [SplashGate] يعدّها.
  final VoidCallback? onLogoTap;

  /// الحديثُ الذي سُمّي منه النظام تحت العلامة.
  final bool showHadith;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Brand.ground,
        child: Semantics(
          label: Brand.name,
          child: Stack(
            children: [
              Center(
                // `opaque` لأن العلامةَ شفافةُ الأطراف: النقرةُ على فراغٍ بين
                // الهلال والنجمة تُحسب نقرةً على الشعار.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLogoTap,
                  child: const BrandGlyph(height: 128),
                ),
              ),
              // العلامةُ تبقى في مكان شاشة أندرويد الأصلية تماماً، والحديثُ يظهر تحتها بعد
              // لحظة — فالانتقالُ من تلك إلى هذه لا يُرى، ثم يُقرأ الحديث.
              if (showHadith)
                const Align(
                  alignment: Alignment(0, 0.42),
                  child: _SplashHadith(),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (caption != null) ...[
                        Text(
                          caption,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: Brand.ribbon),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Brand.ribbon,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الحديثُ على شاشة البدء: يظهر متأخّراً قليلاً ويصعد صعوداً خفيفاً — بلا إطار، فالأرضيةُ
/// أرضيتُه.
class _SplashHadith extends StatefulWidget {
  const _SplashHadith();

  @override
  State<_SplashHadith> createState() => _SplashHadithState();
}

class _SplashHadithState extends State<_SplashHadith>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _reveal.forward();
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic);

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curve),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NzSpace.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  BrandHadith.text,
                  textAlign: TextAlign.center,
                  style: NzType.hadith.copyWith(
                    color: NzBrand.star,
                    fontSize: 20,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: NzSpace.s2),
                Text(
                  BrandHadith.source,
                  style: NzType.label.copyWith(color: Brand.ribbon),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يُبقي [BrandSplash] ظاهرةً حتى يجتمع أمران: أن يجهز التطبيق ([ready])، وأن
/// تمضي [minimum] — ثم يتلاشى إلى [child].
///
/// ثلاثُ نقراتٍ متتابعةٍ على الشعار تفتح [onServerChoice] — اختيارُ الخادم
/// (الرئيسي أو المحلّي). مخفيّةٌ عمداً: لا يحتاجها المستخدمُ العاديّ، ولا يصحّ
/// أن يمرّ بها بالخطأ فيبدّل خادمَه.
///
/// الحدُّ الأدنى لأن استعادة الجلسة من المخزن المحلي تتمّ في جزءٍ من الثانية،
/// فبدونه تومض الشاشةُ ولا تُرى.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.ready,
    required this.child,
    this.caption,
    this.minimum = const Duration(seconds: 1),
    this.onServerChoice,
  });

  final bool ready;
  final Widget child;
  final String? caption;
  final Duration minimum;

  /// تُستدعى بعد ثلاث نقراتٍ على الشعار، وتبقى الشاشةُ قائمةً حتى تنتهي — فلا
  /// تُسحب من تحت النافذة إن جهزت الجلسةُ وهي مفتوحة. `null` يعطّل الإيماءة.
  final Future<void> Function(BuildContext context)? onServerChoice;

  /// نقراتٌ أبعدُ من هذه عن سابقتها لا تُحسب معها.
  static const Duration tapWindow = Duration(milliseconds: 1500);
  static const int tapsNeeded = 3;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  late final Timer _timer;
  Timer? _tapTimer;
  bool _elapsed = false;
  int _taps = 0;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minimum, () => setState(() => _elapsed = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    _tapTimer?.cancel();
    super.dispose();
  }

  /// أولُ نقرةٍ تُمسك الشاشةَ: الحدُّ الأدنى ثانيةٌ واحدة، وثلاثُ نقراتٍ تحتاج
  /// أكثر منها لمن لا يعرفها — فبدون الإمساك تُسحب الشاشةُ من تحت إصبعه.
  void _onLogoTap() {
    _tapTimer?.cancel();
    _taps++;

    if (_taps >= SplashGate.tapsNeeded) {
      _taps = 0;
      _choose();
      return;
    }

    // إعادةُ التوقيت عند كل نقرة تجعل النافذةَ «بين نقرتين» لا «منذ الأولى»،
    // ثم يعيد انقضاؤها تقييمَ الشاشة لتنسحب إن كانت الجلسةُ جاهزة.
    _tapTimer = Timer(SplashGate.tapWindow, () {
      setState(() => _taps = 0);
    });
    setState(() {});
  }

  Future<void> _choose() async {
    final choose = widget.onServerChoice;

    if (choose == null) {
      return;
    }

    setState(() => _choosing = true);

    try {
      await choose(context);
    } finally {
      if (mounted) {
        setState(() => _choosing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final holding = _taps > 0 || _choosing;
    final showSplash = !(widget.ready && _elapsed) || holding;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: showSplash
          ? BrandSplash(
              key: const ValueKey('splash'),
              caption: widget.caption,
              onLogoTap: widget.onServerChoice == null ? null : _onLogoTap,
            )
          : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
    );
  }
}
