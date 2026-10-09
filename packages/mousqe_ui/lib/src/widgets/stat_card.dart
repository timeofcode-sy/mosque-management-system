import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// بطاقة إحصاء (`Metric` في الهوية): تسمية صغيرة ورقمٌ كبير بالكوفي، وأيقونةٌ اختيارية باسمها في [NzIcons].
///
/// الأرقام لاتينية (0–9) كما في كل النظام، بخانات متساوية العرض فتصطفّ الأعمدة.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.hint,
  });

  final String value;
  final String label;

  /// اسمُ أيقونةٍ من [NzIcons] — زخرفيةٌ فلا اسمَ لها في شجرة الإتاحة (التسمية تكفي).
  final String? icon;

  /// سطرٌ ثانوي تحت الرقم («من أصل 30 يوماً»).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: NzSpace.s4,
          vertical: NzSpace.s3,
        ),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(NzRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  NzIcon(icon!, size: 18, color: c.bronzeInk),
                  const SizedBox(width: NzSpace.s2),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NzType.label.copyWith(color: c.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NzSpace.s1),
            Text(
              value,
              style: NzType.display3.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (hint != null)
              Text(hint!, style: NzType.caption.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }
}
