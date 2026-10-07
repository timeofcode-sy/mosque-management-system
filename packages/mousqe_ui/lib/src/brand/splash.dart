import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

/// شاشةُ البدء: العلامةُ وسطَ الأرضية الخضراء، بنفس لونِ شاشة أندرويد الأصلية
/// ومقاسِها (128dp) — فتنتقل هذه من تلك دون أن يلحظ المستخدمُ أنهما شاشتان.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key, this.caption});

  /// اسمُ التطبيق أسفلَ الشاشة — «تطبيق الأستاذ»، «إدارة المعهد».
  final String? caption;

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
              const Center(child: BrandGlyph(height: 128)),
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

/// يُبقي [BrandSplash] ظاهرةً حتى يجتمع أمران: أن يجهز التطبيق ([ready])، وأن
/// تمضي [minimum] — ثم يتلاشى إلى [child].
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
  });

  final bool ready;
  final Widget child;
  final String? caption;
  final Duration minimum;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  late final Timer _timer;
  bool _elapsed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minimum, () => setState(() => _elapsed = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSplash = !(widget.ready && _elapsed);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: showSplash
          ? BrandSplash(key: const ValueKey('splash'), caption: widget.caption)
          : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
    );
  }
}
