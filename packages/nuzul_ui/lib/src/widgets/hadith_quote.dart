import 'package:flutter/material.dart';

import '../generated/tokens.dart';
import '../theme.dart';

/// The hadith or a Quranic passage, in Amiri with full tashkeel, always with its source.
class NzHadithQuote extends StatelessWidget {
  const NzHadithQuote(this.text, {super.key, required this.source, this.night = false});

  final String text;
  final String source;

  /// On the brand ground (splash, onboarding, the home screen header).
  final bool night;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final ink = night ? NzBrand.star : c.ink;
    final src = night ? NzBrand.bronze : c.bronzeInk;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(NzSpace.s5, NzSpace.s5, NzSpace.s5, NzSpace.s4),
      decoration: BoxDecoration(
        color: night ? NzBrand.night : c.surfaceRaised,
        border: Border.all(color: night ? NzBrand.nightLine : c.line),
        borderRadius: BorderRadius.circular(NzRadius.md),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text, textAlign: TextAlign.center, style: NzType.hadith.copyWith(color: ink)),
        const SizedBox(height: NzSpace.s2),
        Text(source, style: NzType.label.copyWith(color: src)),
      ]),
    );
  }
}
