import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// بطاقةُ الأجزاء الثلاثين ([NzJuzProgress]): ثلاثون خطّاً بزاوية الشعار — ما حُفظ، وما يُحفظ
/// الآن أطولَ منها بالنحاس، وما بقي. يقرؤها الأستاذ ووليُّ الأمر والطالب والمشرف بنظرةٍ واحدة.
class JuzProgressCard extends StatelessWidget {
  const JuzProgressCard({
    super.key,
    required this.memorized,
    this.current,
    this.title = 'الأجزاء',
    this.margin = EdgeInsets.zero,
  });

  /// أرقامُ الأجزاء المحفوظة (1–30).
  final Set<int> memorized;

  /// الجزءُ الذي يُحفظ الآن.
  final int? current;
  final String title;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(NzSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                NzIcon(NzIcons.mushaf, size: 18, color: c.bronzeInk),
                const SizedBox(width: NzSpace.s2),
                Text(
                  title,
                  style: NzType.label.copyWith(
                    color: c.bronzeInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: NzSpace.s3),
            NzJuzProgress(memorized: memorized, current: current),
          ],
        ),
      ),
    );
  }
}
