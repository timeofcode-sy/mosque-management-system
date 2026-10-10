import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// نبرةُ الشارة أو التنبيه: أزواجُ الهوية الثابتة (نصٌّ بلونٍ على خلفيته الهادئة).
enum StatusTone {
  /// حاضر / مكتمل / مقبول — success.
  success,

  /// متأخر / قيد المراجعة — warning.
  warning,

  /// غائب / مرفوض / خطأ — danger.
  danger,

  /// غائب بعذر / معلومة — info.
  info,

  /// محايد: مسودّة، موقوف — نصٌّ ثانوي على أرضيةٍ غائرة.
  neutral,

  /// نحاسٌ هادئ: الوسوم الخاصة («لحلقتي»، «المعهد العامل»).
  bronze;

  /// (الأمامية، الخلفية) في السمة الحالية.
  (Color, Color) colors(NzColorTokens c) => switch (this) {
        StatusTone.success => (c.success, c.successSoft),
        StatusTone.warning => (c.warning, c.warningSoft),
        StatusTone.danger => (c.danger, c.dangerSoft),
        StatusTone.info => (c.info, c.infoSoft),
        StatusTone.neutral => (c.inkMuted, c.surfaceSunken),
        StatusTone.bronze => (c.bronzeInk, c.bronzeSoft),
      };
}

/// شارةُ حالةٍ عامّة: كلمةٌ وأيقونةٌ اختيارية على خلفيتها الهادئة، بزاوية `radius-sm` لا بكبسولة.
/// اللونُ لا يحمل المعنى وحده — الكلمةُ دائماً.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = StatusTone.neutral, this.icon});

  final String label;
  final StatusTone tone;

  /// اسمُ أيقونةٍ من [NzIcons].
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context.nz);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(NzSpace.s2, 2, NzSpace.s3, 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NzRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            NzIcon(icon!, size: 16, color: fg),
            const SizedBox(width: NzSpace.s1),
          ],
          Text(label, style: NzType.label.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// شريطُ تنبيهٍ داخل الشاشة: أيقونةٌ ونصٌّ يقول ما حدث وكيف يُصلح، على خلفيةٍ هادئة.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(
    this.message, {
    super.key,
    this.tone = StatusTone.info,
    this.icon = NzIcons.informationCircle,
  });

  final String message;
  final StatusTone tone;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context.nz);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: NzSpace.s3, vertical: NzSpace.s3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NzRadius.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NzIcon(icon, size: 18, color: fg),
          const SizedBox(width: NzSpace.s2),
          Expanded(child: Text(message, style: NzType.body.copyWith(color: fg))),
        ],
      ),
    );
  }
}
