import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../data/views.dart';
import '../di/app_scope.dart';

/// تسجيل التسميع.
///
/// **لا أسطر ولا نقاط تُحسب هنا.** الخادم يحسبهما من المدى ويجمّدهما وقت
/// التسجيل ([API.md §6](../../../../../docs/API.md))، فحسابُهما في العميل يخلق
/// مصدرَ حقيقةٍ ثانياً يختلف عن الأول عند أول تعديلٍ في جدول الأسطر.
/// وحدَه حدُّ رقم الآية يُتحقَّق محلياً — لأن رفضه من الخادم يأتي بعد ساعات.
class RecitationScreen extends StatefulWidget {
  const RecitationScreen({
    super.key,
    required this.session,
    required this.entry,
  });

  final SessionView session;
  final RosterEntry entry;

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromAyah = TextEditingController(text: '1');
  final _toAyah = TextEditingController(text: '1');
  final _notes = TextEditingController();

  RecitationType _type = RecitationType.hifz;
  RecitationGrade? _grade = RecitationGrade.excellent;
  int _fromSurah = 1;
  int _toSurah = 1;
  bool _busy = false;

  @override
  void dispose() {
    _fromAyah.dispose();
    _toAyah.dispose();
    _notes.dispose();
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
      await deps.repository.saveRecitation(
        session: widget.session,
        studentUuid: widget.entry.studentUuid,
        type: _type,
        fromSurah: _fromSurah,
        fromAyah: int.parse(_fromAyah.text),
        toSurah: _toSurah,
        toAyah: int.parse(_toAyah.text),
        grade: _grade,
        notes: _notes.text.trim(),
      );

      deps.sync.syncNow();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'صُفَّ التسميع للمزامنة — الأسطر والنقاط يحسبها الخادم.',
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
    final canRecord = widget.session.exists;

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل تسميع')),
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
            if (!canRecord)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                // التسميع يُعلَّق على جلسة، فلا بدّ من فتحها أولاً — والفتحُ يقع
                // بحفظ التفقّد ولو بلا شبكة.
                child: Text('افتح جلسة اليوم من شاشة التفقّد أولاً.'),
              ),
            SegmentedButton<RecitationType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: RecitationType.hifz, label: Text('حفظ')),
                ButtonSegment(
                  value: RecitationType.murajaa,
                  label: Text('مراجعة'),
                ),
                ButtonSegment(
                  value: RecitationType.tilawah,
                  label: Text('تلاوة'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (values) =>
                  setState(() => _type = values.first),
            ),
            const SizedBox(height: 16),
            _SurahRow(
              label: 'من',
              surah: _fromSurah,
              ayahController: _fromAyah,
              onSurah: (value) => setState(() => _fromSurah = value),
            ),
            const SizedBox(height: 12),
            _SurahRow(
              label: 'إلى',
              surah: _toSurah,
              ayahController: _toAyah,
              onSurah: (value) => setState(() => _toSurah = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecitationGrade?>(
              initialValue: _grade,
              decoration: const InputDecoration(labelText: 'التقدير'),
              items: const [
                DropdownMenuItem(
                  value: RecitationGrade.excellent,
                  child: Text('ممتاز'),
                ),
                DropdownMenuItem(
                  value: RecitationGrade.veryGood,
                  child: Text('جيد جداً'),
                ),
                DropdownMenuItem(
                  value: RecitationGrade.good,
                  child: Text('جيد'),
                ),
                DropdownMenuItem(value: null, child: Text('بلا تقدير')),
              ],
              onChanged: (value) => setState(() => _grade = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy || !canRecord ? null : _submit,
              child: const Text('حفظ التسميع'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.label,
    required this.surah,
    required this.ayahController,
    required this.onSurah,
  });

  final String label;
  final int surah;
  final TextEditingController ayahController;
  final ValueChanged<int> onSurah;

  @override
  Widget build(BuildContext context) {
    final total = Quran.ayahs(surah);

    return Row(
      spacing: 12,
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: surah,
            isExpanded: true,
            decoration: InputDecoration(labelText: '$label — السورة'),
            items: [
              for (final item in Quran.all)
                DropdownMenuItem(
                  value: item.number,
                  child: Text('${item.number}. ${item.name}'),
                ),
            ],
            onChanged: (value) => value == null ? null : onSurah(value),
          ),
        ),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: ayahController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'الآية',
              helperText: 'من 1 إلى $total',
            ),
            validator: (value) {
              final ayah = int.tryParse((value ?? '').trim());

              if (ayah == null || ayah < 1 || ayah > total) {
                return 'بين 1 و$total';
              }

              return null;
            },
          ),
        ),
      ],
    );
  }
}
