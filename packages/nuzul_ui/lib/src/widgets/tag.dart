import 'package:flutter/material.dart';

import '../generated/tokens.dart';
import '../icons.dart';
import '../theme.dart';

/// A chamfered label, its corner cut at the roof angle. Not a button.
class NzTag extends StatelessWidget {
  const NzTag(this.text, {super.key, this.bronze = false, this.icon});

  final String text;

  /// Bronze inside cards; the default night tag for light grounds and posters.
  final bool bronze;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final bg = bronze ? c.bronzeSoft : c.tagBg;
    final fg = bronze ? c.bronzeInk : c.tagInk;
    return ClipPath(
      clipper: const _ChamferClipper(),
      child: Container(
        color: bg,
        padding: const EdgeInsetsDirectional.fromSTEB(NzSpace.s3, NzSpace.s1, NzSpace.s3 + 6, NzSpace.s1),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[NzIcon(icon!, size: 14, color: fg), const SizedBox(width: NzSpace.s1)],
          Text(text, style: NzType.label.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ChamferClipper extends CustomClipper<Path> {
  const _ChamferClipper();

  static const _cut = 12.0;

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(_cut, s.height)
    ..lineTo(0, s.height - _cut * nzSlope)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
