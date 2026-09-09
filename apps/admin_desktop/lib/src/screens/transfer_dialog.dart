import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';

/// نقلُ طالبٍ بين حلقتين في الدورة نفسها — ✅ م.6.5، نوعُ `student.transfer`.
///
/// **والتسجيلُ القديم يُغلق «منقولاً» ولا يُحذف** (`TransferStudent` على الخادم):
/// حضورُ الطالب في حلقته الأولى يبقى مقروءاً في التقارير، وهو الفرقُ بين نقلٍ
/// وحذفٍ ثم تسجيلٍ جديد. ويُقال ذلك في الحوار صراحةً، فمن ينقل يعرف ما يبقى.
Future<void> showTransferDialog(
  BuildContext context, {
  required StudentListEntry student,
}) async {
  final deps = AppScope.of(context);
  final circles = await deps.circles.loadCircles();

  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => _TransferDialog(student: student, circles: circles),
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.student, required this.circles});

  final StudentListEntry student;
  final List<CircleView> circles;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _reason = TextEditingController();
  String? _target;
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // حلقتُه الحالية ليست وجهةً — نقلُ الطالب إلى حلقته نفسِها لا معنى له،
    // وعرضُها في القائمة دعوةٌ إلى عمليةٍ يرفضها الخادم.
    final targets = widget.circles
        .where((circle) => circle.circleName != widget.student.circleName)
        .toList();

    return AlertDialog(
      title: Text('نقل ${widget.student.fullName}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              widget.student.circleName == null
                  ? 'الطالب غير مسجَّل في حلقةٍ الآن — سيُسجَّل في الحلقة المختارة.'
                  : 'من «${widget.student.circleName}» — ويبقى تسجيلُه القديم '
                        'مغلقاً «منقولاً» فلا يضيع حضورُه فيه.',
              style: theme.textTheme.bodySmall,
            ),
            DropdownButtonFormField<String>(
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الحلقة الجديدة',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final circle in targets)
                  DropdownMenuItem(
                    value: circle.uuid,
                    child: Text(
                      '${circle.circleName} — ${circle.shiftName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _target = value),
            ),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'سبب النقل (اختياري)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _target == null || _saving ? null : _transfer,
          child: const Text('نقل'),
        ),
      ],
    );
  }

  Future<void> _transfer() async {
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await AppScope.of(context).students.transferStudent(
          studentUuid: widget.student.uuid,
          toCourseCircleUuid: _target!,
          reason: _reason.text,
        );

    messenger.showSnackBar(
      const SnackBar(content: Text('صُفَّ النقلُ للمزامنة.')),
    );

    navigator.pop();
  }
}
