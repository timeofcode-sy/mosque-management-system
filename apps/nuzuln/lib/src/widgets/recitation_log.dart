import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

/// سجلُّ التسميع تحت شريط الأجزاء — في «حفظي» للطالب ولسانِ «الحفظ» لوليّ الأمر.
///
/// حلّ محلَّ نسبةٍ مئوية لكل جزء: النسبةُ تقول «كم بقي» ولا تقول ماذا سمّع اليوم ولا كيف،
/// والسجلُّ يقول المقطعَ والتقديرَ والنقاط يوماً بيوم — وهو ما يسأل عنه الأبُ ابنَه.
class RecitationLog extends StatelessWidget {
  const RecitationLog({super.key, required this.entries});

  final List<RecitationLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NzSpace.s4, NzSpace.s5, NzSpace.s4, NzSpace.s2),
          child: Row(
            children: [
              Expanded(
                child: Text('سجلّ التسميع', style: Theme.of(context).textTheme.titleMedium),
              ),
              if (entries.isNotEmpty)
                Text(
                  'آخر ${entries.length} تسميعاً',
                  style: NzType.caption.copyWith(color: c.inkMuted),
                ),
            ],
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(NzSpace.s5),
            child: Text(
              'لم يُسجَّل تسميعٌ بعد.',
              textAlign: TextAlign.center,
              style: NzType.body.copyWith(color: c.inkMuted),
            ),
          )
        else
          for (final entry in entries) _EntryCard(entry: entry),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final RecitationLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    // ألوانُ اللوحة نفسُها (`RecitationGrade::color`): ممتازٌ أخضر، جيدٌ جداً كهرمانيّ، جيدٌ محايد.
    final tone = switch (entry.grade) {
      'excellent' => StatusTone.success,
      'very_good' => StatusTone.warning,
      _ => StatusTone.neutral,
    };

    return Card(
      margin: const EdgeInsets.fromLTRB(NzSpace.s4, NzSpace.s1, NzSpace.s4, NzSpace.s1),
      child: Padding(
        padding: const EdgeInsets.all(NzSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: NzSpace.s2,
          children: [
            Row(
              spacing: NzSpace.s2,
              children: [
                NzIcon(NzIcons.mushaf, size: 18, color: c.bronzeInk),
                Expanded(
                  child: Text(
                    entry.range,
                    style: NzType.label.copyWith(color: c.ink),
                  ),
                ),
                if (entry.gradeLabel != null) StatusBadge(entry.gradeLabel!, tone: tone),
              ],
            ),
            Text(
              [
                if (entry.date != null) formatLongDate(entry.date!, withYear: false),
                if (entry.typeLabel != null) entry.typeLabel!,
                if (entry.lines > 0) '${_number(entry.lines)} سطراً',
                if (entry.points != 0) '${_number(entry.points)} نقطة',
              ].join(' · '),
              style: NzType.caption.copyWith(color: c.inkMuted),
            ),
            if (entry.notes?.trim().isNotEmpty == true)
              Text(entry.notes!.trim(), style: NzType.body.copyWith(color: c.ink)),
          ],
        ),
      ),
    );
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : value.toStringAsFixed(1);
}
