import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../data/views.dart';
import '../di/app_scope.dart';

/// منح نقاطٍ يدوية — `points.award` ([API.md §6](../../../../../docs/API.md)).
class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key, required this.session, required this.entry});

  final SessionView session;
  final RosterEntry entry;

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _points = TextEditingController(text: '1');
  final _note = TextEditingController();

  PointsReason _reason = PointsReason.participation;
  bool _busy = false;

  static const _labels = {
    PointsReason.behavior: 'سلوك',
    PointsReason.participation: 'مشاركة',
    PointsReason.competition: 'مسابقة',
    PointsReason.reward: 'مكافأة',
    PointsReason.excellence: 'تميّز',
    PointsReason.volunteering: 'تطوّع',
    PointsReason.other: 'أخرى',
  };

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
        studentUuid: widget.entry.studentUuid,
        points: double.parse(_points.text.trim()),
        reason: _reason,
        note: _note.text.trim(),
        // تُربط بالجلسة إن كانت مفتوحة، وتبقى صالحةً بدونها.
        session: widget.session.exists ? widget.session : null,
      );

      deps.sync.syncNow();
      messenger.showSnackBar(
        const SnackBar(content: Text('صُفَّت النقاط للمزامنة.')),
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
      appBar: AppBar(title: const Text('منح نقاط')),
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
                for (final entry in _labels.entries)
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
              child: const Text('منح'),
            ),
          ],
        ),
      ),
    );
  }
}
