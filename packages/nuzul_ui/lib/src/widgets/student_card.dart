import 'package:flutter/material.dart';

import '../generated/tokens.dart';
import '../icons.dart';
import '../theme.dart';
import 'attendance.dart';
import 'juz_progress.dart';

/// A student at a glance: name, halaqa, today's attendance, memorisation and the next recitation.
/// The avatar is the brand hexagon; the app shows no student photos.
class NzStudentCard extends StatelessWidget {
  const NzStudentCard({
    super.key,
    required this.name,
    required this.memorized,
    this.halaqa,
    this.lastSeen,
    this.status,
    this.current,
    this.assignment,
    this.onTap,
  });

  final String name;
  final Set<int> memorized;
  final String? halaqa;
  final String? lastSeen;
  final NzAttendance? status;
  final int? current;
  final String? assignment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final meta = [halaqa, lastSeen].whereType<String>().join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(NzSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const NzHexAvatar(),
              const SizedBox(width: NzSpace.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: NzType.bodyLg.copyWith(fontWeight: FontWeight.w600, color: c.ink, height: 1.5)),
                  if (meta.isNotEmpty) Text(meta, style: NzType.caption.copyWith(color: c.inkMuted)),
                ]),
              ),
              if (status != null) NzAttendanceBadge(status!),
            ]),
            const SizedBox(height: NzSpace.s4),
            NzJuzProgress(memorized: memorized, current: current, compact: true),
            if (assignment != null) ...[
              const SizedBox(height: NzSpace.s3),
              Divider(color: c.line),
              const SizedBox(height: NzSpace.s3),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('التسميع القادم', style: NzType.label.copyWith(color: c.inkMuted)),
                const SizedBox(width: NzSpace.s2),
                Expanded(child: Text(assignment!, style: NzType.body.copyWith(color: c.ink))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The brand hexagon used in place of a photo.
class NzHexAvatar extends StatelessWidget {
  const NzHexAvatar({super.key, this.size = 44, this.icon = NzIcons.students});

  final double size;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    return ClipPath(
      clipper: const _HexClipper(),
      child: Container(
        width: size,
        height: size * 50 / 44,
        color: c.surfaceSunken,
        alignment: Alignment.center,
        child: NzIcon(icon, size: size / 2, color: c.inkMuted),
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width / 2, 0)
    ..lineTo(s.width, s.height * .21)
    ..lineTo(s.width, s.height * .79)
    ..lineTo(s.width / 2, s.height)
    ..lineTo(0, s.height * .79)
    ..lineTo(0, s.height * .21)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
