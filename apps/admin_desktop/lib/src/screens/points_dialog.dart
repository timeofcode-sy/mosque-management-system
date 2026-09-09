import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';

/// منحُ نقاطٍ يدوية وتصحيحُها — `points.award`
/// ([API.md §6](../../../../../docs/API.md)).
///
/// والتصحيح إعادةُ إرسالٍ بنفس `uuid` لا منحةٌ ثانية، كما في حوار التسميع.
Future<void> showPointsDialog({
  required BuildContext context,
  required SessionView session,
  required RosterEntry entry,
  PointEntry? award,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _PointsDialog(session: session, entry: entry, award: award),
  );
}

class _PointsDialog extends StatefulWidget {
  const _PointsDialog({
    required this.session,
    required this.entry,
    this.award,
  });

  final SessionView session;
  final RosterEntry entry;
  final PointEntry? award;

  @override
  State<_PointsDialog> createState() => _PointsDialogState();
}

class _PointsDialogState extends State<_PointsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _points;
  late final TextEditingController _note;

  late PointsReason _reason;
  bool _busy = false;

  bool get _isEditing => widget.award != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.award;

    _points = TextEditingController(text: _number(existing?.points ?? 1));
    _note = TextEditingController(text: existing?.note ?? '');
    _reason = existing?.reason ?? PointsReason.participation;
  }

  /// `2.0` ⇒ `2` و`2.5` ⇒ `2.5` — الرقم كما يُكتب لا كما يخزَّن.
  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  void dispose() {
    _points.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing
            ? 'تعديل نقاط ${widget.entry.fullName}'
            : 'منح نقاط لـ${widget.entry.fullName}',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _points,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'النقاط',
                        helperText: 'يقبل السالب للخصم',
                      ),
                      validator: (value) =>
                          double.tryParse((value ?? '').trim()) == null
                          ? 'أدخل رقماً'
                          : null,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<PointsReason>(
                      initialValue: _reason,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'السبب'),
                      items: [
                        for (final entry in pointsReasonLabels.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _reason = value ?? _reason),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظة'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_isEditing ? 'حفظ التعديل' : 'منح'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) {
      return;
    }

    setState(() => _busy = true);
    final deps = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await deps.circles.awardPoints(
        studentId: widget.entry.studentId,
        studentUuid: widget.entry.studentUuid,
        points: double.parse(_points.text.trim()),
        reason: _reason,
        note: _note.text.trim(),
        session: widget.session,
        // تُربط بالجلسة إن كانت مفتوحة، وتبقى صالحةً بدونها.
        linkToSession: widget.session.exists,
        uuid: widget.award?.uuid,
      );

      deps.sync.syncNow();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'صُفَّ تعديل النقاط للمزامنة.'
                : 'صُفَّت النقاط للمزامنة.',
          ),
        ),
      );
      navigator.pop();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
