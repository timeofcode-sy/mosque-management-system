import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

/// الجانبُ السلوكي لطالب — يعرضه الأستاذ في ملف طالبه، ووليُّ الأمر في ملف ابنه، والطالبُ لنفسه.
///
/// الملاحظةُ تُعرض **كاملةً** لا مقصوصة: هي كلامُ أستاذٍ عن الطالب، وقصُّها يغيّر معناها. ولونُها
/// من نوعها: ثناءٌ أخضر، وتنبيهٌ أحمر، ومجرّدةٌ بلون النص الخافت.
class BehaviorSection extends StatelessWidget {
  const BehaviorSection({super.key, required this.behavior});

  final StudentBehavior behavior;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: _Count(
                  value: behavior.positive,
                  label: 'ثناء',
                  icon: NzIcons.checkCircle,
                  color: c.success,
                ),
              ),
              Expanded(
                child: _Count(
                  value: behavior.negative,
                  label: 'تنبيه',
                  icon: NzIcons.warning,
                  color: c.danger,
                ),
              ),
              Expanded(
                child: _Count(
                  value: behavior.neutral,
                  label: 'ملاحظة',
                  icon: NzIcons.note,
                  color: c.inkMuted,
                ),
              ),
            ],
          ),
        ),
        if (behavior.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'لم يكتب الأساتذة ملاحظاتٍ سلوكية بعد.',
              textAlign: TextAlign.center,
              style: NzType.body.copyWith(color: c.inkMuted),
            ),
          ),
        if (behavior.traits.isNotEmpty) ...[
          const _Title('الصفات'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final trait in behavior.traits) _TraitChip(trait: trait),
              ],
            ),
          ),
        ],
        if (behavior.notes.isNotEmpty) ...[
          const _Title('ملاحظات الأساتذة'),
          for (final note in behavior.notes) _NoteCard(note: note),
        ],
        if (behavior.points.isNotEmpty) ...[
          _Title('نقاط السلوك · ${_signed(behavior.behaviorPoints)}'),
          for (final point in behavior.points)
            ListTile(
              dense: true,
              leading: NzIcon(
                NzIcons.star,
                color: point.points < 0 ? c.danger : c.success,
              ),
              title: Text(
                point.note?.trim().isNotEmpty == true
                    ? point.note!
                    : 'نقاط سلوك',
              ),
              subtitle: point.date == null
                  ? null
                  : Text(formatLongDate(point.date!, withWeekday: false)),
              trailing: Text(
                _signed(point.points),
                style: NzType.label.copyWith(
                  color: point.points < 0 ? c.danger : c.success,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  static String _signed(double value) {
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    return value > 0 ? '+$text' : text;
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            NzIcon(icon, color: color),
            const SizedBox(height: 4),
            Text('$value', style: NzType.title.copyWith(color: color)),
            Text(
              label,
              style: NzType.caption.copyWith(color: context.nz.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final BehaviorNote note;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final (color, icon, kind) = switch (note.polarity) {
      'positive' => (c.success, NzIcons.checkCircle, 'ثناء'),
      'negative' => (c.danger, NzIcons.warning, 'تنبيه'),
      _ => (c.inkMuted, NzIcons.note, 'ملاحظة'),
    };

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: c.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شريطٌ ملوّن على حافّة البطاقة يقول نوعَ الملاحظة قبل قراءتها.
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Row(
                      spacing: 6,
                      children: [
                        NzIcon(icon, size: 16, color: color),
                        Text(kind, style: NzType.label.copyWith(color: color)),
                        const Spacer(),
                        Text(
                          [
                            if (note.date != null)
                              formatLongDate(note.date!, withWeekday: false),
                            if (note.circle != null) note.circle!,
                          ].join(' · '),
                          style: NzType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                    Text(note.note, style: NzType.body.copyWith(color: c.ink)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.trait});

  final BehaviorTrait trait;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final (background, foreground) = switch (trait.polarity) {
      'positive' => (c.successSoft, c.success),
      'negative' => (c.dangerSoft, c.danger),
      _ => (c.surfaceSunken, c.ink),
    };
    final note = trait.note?.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: trait.name,
              style: NzType.label.copyWith(color: foreground),
            ),
            if (note != null && note.isNotEmpty)
              TextSpan(
                text: ' — $note',
                style: NzType.caption.copyWith(color: foreground),
              ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
