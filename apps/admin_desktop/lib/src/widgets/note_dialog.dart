import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

/// «ثناء» أو «تنبيه» أو «ملاحظة» — نفسُ ما يقرؤه وليُّ الأمر في الجانب السلوكي.
String noteKindLabel(NotePolarity? polarity) => switch (polarity) {
  NotePolarity.positive => 'ثناء',
  NotePolarity.negative => 'تنبيه',
  null => 'ملاحظة',
};

/// ملاحظةُ التفقّد ونوعُها معاً: النوعُ يدخل في مقياس «الأدب» وفي الجانب السلوكي
/// الذي يراه وليُّ الأمر، فلا يُترك للتخمين من نصّها.
///
/// تعود بـ`(النص, النوع)`، والنصُّ الفارغ يعني حذفَ الملاحظة.
class NoteDialog extends StatefulWidget {
  const NoteDialog({
    super.key,
    required this.title,
    required this.note,
    required this.polarity,
  });

  final String title;
  final String note;
  final NotePolarity? polarity;

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final _controller = TextEditingController(text: widget.note);
  late NotePolarity? _polarity = widget.polarity;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            SegmentedButton<NotePolarity?>(
              showSelectedIcon: false,
              segments: [
                for (final polarity in const [
                  NotePolarity.positive,
                  NotePolarity.negative,
                  null,
                ])
                  ButtonSegment(
                    value: polarity,
                    label: Text(noteKindLabel(polarity)),
                  ),
              ],
              selected: {_polarity},
              onSelectionChanged: (values) =>
                  setState(() => _polarity = values.first),
            ),
            TextField(controller: _controller, autofocus: true, maxLines: 3),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((_controller.text.trim(), _polarity)),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
