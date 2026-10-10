import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

import 'snapshot_view.dart';
import 'status_badge.dart';

/// بطاقةُ إعلانٍ واحدة — مشتركةٌ بين تطبيقات الطالب وولي الأمر والأستاذ (كلٌّ يقرأ ما وُجِّه إليه).
///
/// بلا اعتمادٍ على نماذج `mousqe_core` فتأخذ حقولَها جاهزة. والشارةُ ([circleBadge]) تقول للقارئ إن الإعلانَ
/// يخصّه هو لا المعهدَ كلَّه — فيقدّر أهميّتَه بلا أن يعرف بقيّةَ المشمولين.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.title,
    required this.body,
    this.publishedAt,
    this.circleBadge,
  });

  final String title;
  final String body;

  /// تاريخُ النشر كما وصل (ISO) — يُنسَّق «اليوم 08:12».
  final String? publishedAt;

  /// نصُّ الشارة إن كان الإعلانُ لحلقةٍ بعينها («لحلقتي»، «لحلقة ابني»)، وإلا `null`.
  final String? circleBadge;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final at = publishedAt == null ? null : DateTime.tryParse(publishedAt!);

    return Card(
      margin: const EdgeInsets.fromLTRB(NzSpace.s4, NzSpace.s2, NzSpace.s4, 0),
      child: Padding(
        padding: const EdgeInsets.all(NzSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: NzType.title.copyWith(fontSize: 17, color: c.ink),
                  ),
                ),
                if (circleBadge != null)
                  StatusBadge(circleBadge!, tone: StatusTone.bronze),
              ],
            ),
            const SizedBox(height: NzSpace.s2),
            Text(body, style: NzType.body.copyWith(color: c.ink)),
            if (publishedAt != null) ...[
              const SizedBox(height: NzSpace.s2),
              Text(
                at == null ? publishedAt! : formatStamp(at),
                style: NzType.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
