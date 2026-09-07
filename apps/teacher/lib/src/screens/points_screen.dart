import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../data/labels.dart';
import '../data/views.dart';
import '../di/app_scope.dart';

/// منح نقاطٍ يدوية وتصحيحُها — `points.award` ([API.md §6](../../../../../docs/API.md)).
///
/// التصحيح إعادةُ إرسالٍ بنفس `uuid` لا منحةٌ ثانية، كما في شاشة التسميع.
class PointsScreen extends StatefulWidget {
  const PointsScreen({
    super.key,
    required this.session,
    required this.entry,
    this.award,
  });

  final SessionView session;
  final RosterEntry entry;

  /// منحةٌ مسجَّلة تُفتح لتصحيحها — و`null` تعني منحةً جديدة.
  final PointEntry? award;

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
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

  /// `2.0` ⇒ `2` و`2.5` ⇒ `2.5` — الرقم كما يكتبه الأستاذ لا كما يخزَّن.
  static String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : '$value';

  @override
  void dispose() {
    _points.dispose();
    _note.dispose();
    super.dispose();
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
      await deps.repository.awardPoints(
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
            _isEditing ? 'صُفَّ تعديل النقاط للمزامنة.' : 'صُفَّت النقاط للمزامنة.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل النقاط' : 'منح نقاط')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.entry.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _points,
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
            const SizedBox(height: 12),
            DropdownButtonFormField<PointsReason>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'السبب'),
              items: [
                for (final entry in pointsReasonLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _reason = value ?? _reason),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_isEditing ? 'حفظ التعديل' : 'منح'),
            ),
          ],
        ),
      ),
    );
  }
}
