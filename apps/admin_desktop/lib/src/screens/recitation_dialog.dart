import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';

/// تسجيلُ التسميع وتصحيحُه — **حوارٌ لا شاشة**.
///
/// وهذا هو الفرقُ عن تطبيق الأستاذ: هناك شاشةٌ تُدفَع فوق المكدّس لأن الهاتف لا
/// يسع اثنتين، وهنا حوارٌ فوق الكشف فيبقى الطالبُ وصفُّه ظاهرين خلفه.
///
/// **وقواعدُ المدى ليست هنا:** الجزءُ يقيّد السورتين، و«إلى» لا تسبق «من»،
/// والآيةُ محدودةٌ بسورتها — كلُّه في [RecitationDraft] داخل `mousqe_core`،
/// تستدعيه هذه الشاشةُ وشاشةُ الأستاذ بحرفه. وما هنا **رسمُ الحقول لا حكمُها**.
///
/// **ولا أسطرَ ولا نقاطَ تُحسب:** الخادم يحسبهما من المدى ويجمّدهما وقت التسجيل
/// ([API.md §6](../../../../../docs/API.md)).
Future<void> showRecitationDialog({
  required BuildContext context,
  required SessionView session,
  required RosterEntry entry,
  RecitationEntry? recitation,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RecitationDialog(
      session: session,
      entry: entry,
      recitation: recitation,
    ),
  );
}

class _RecitationDialog extends StatefulWidget {
  const _RecitationDialog({
    required this.session,
    required this.entry,
    this.recitation,
  });

  final SessionView session;
  final RosterEntry entry;
  final RecitationEntry? recitation;

  @override
  State<_RecitationDialog> createState() => _RecitationDialogState();
}

class _RecitationDialogState extends State<_RecitationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fromAyah;
  late final TextEditingController _toAyah;
  late final TextEditingController _notes;
  late final RecitationDraft _draft;

  bool _busy = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.recitation;

    _draft = existing == null
        ? RecitationDraft()
        : RecitationDraft.from(
            uuid: existing.uuid,
            type: existing.type,
            grade: existing.grade,
            fromSurah: existing.fromSurah,
            fromAyah: existing.fromAyah,
            toSurah: existing.toSurah,
            toAyah: existing.toAyah,
            juz: existing.juz,
            notes: existing.notes,
          );

    _fromAyah = TextEditingController(text: '${_draft.fromAyah}');
    _toAyah = TextEditingController(text: '${_draft.toAyah}');
    _notes = TextEditingController(text: _draft.notes ?? '');
  }

  @override
  void dispose() {
    _fromAyah.dispose();
    _toAyah.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// الحقلان النصّيان يتبعان المسوّدة: تغييرُ الجزء أو السورة يعيد ضبط المدى فيهما.
  void _sync(void Function() change) {
    setState(() {
      change();
      _fromAyah.text = '${_draft.fromAyah}';
      _toAyah.text = '${_draft.toAyah}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = widget.session.exists;

    return AlertDialog(
      title: Text(
        _draft.isEditing
            ? 'تعديل تسميع ${widget.entry.fullName}'
            : 'تسميع ${widget.entry.fullName}',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!canRecord)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    // التسميع يُعلَّق على جلسة، فلا بدّ من فتحها أولاً — والفتحُ
                    // يقع بحفظ التفقّد ولو بلا شبكة.
                    child: Text('افتح جلسة اليوم بحفظ التفقّد أولاً.'),
                  ),
                SegmentedButton<RecitationType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: RecitationType.hifz,
                      label: Text('حفظ'),
                    ),
                    ButtonSegment(
                      value: RecitationType.murajaa,
                      label: Text('مراجعة'),
                    ),
                    ButtonSegment(
                      value: RecitationType.tilawah,
                      label: Text('تلاوة'),
                    ),
                  ],
                  selected: {_draft.type},
                  onSelectionChanged: (values) =>
                      setState(() => _draft.type = values.first),
                ),
                const SizedBox(height: 16),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      // الجزء أولاً: هو ما يقيّد القائمتين تحته.
                      child: DropdownButtonFormField<int>(
                        initialValue: _draft.juz,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'الجزء'),
                        items: [
                          for (var juz = 1; juz <= 30; juz++)
                            DropdownMenuItem(
                              value: juz,
                              child: Text('الجزء $juz'),
                            ),
                        ],
                        onChanged: (value) => value == null
                            ? null
                            : _sync(() => _draft.pickJuz(value)),
                      ),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<RecitationGrade?>(
                        initialValue: _draft.grade,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'التقدير'),
                        items: [
                          for (final entry in recitationGradeLabels.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          const DropdownMenuItem(
                            value: null,
                            child: Text('بلا تقدير'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _draft.grade = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RangeRow(
                  label: 'من',
                  surah: _draft.fromSurah,
                  surahs: _draft.fromSurahOptions,
                  ayahController: _fromAyah,
                  onSurah: (surah) => _sync(() => _draft.pickFromSurah(surah)),
                  validator: _draft.fromAyahError,
                ),
                const SizedBox(height: 12),
                _RangeRow(
                  label: 'إلى',
                  surah: _draft.toSurah,
                  surahs: _draft.toSurahOptions,
                  ayahController: _toAyah,
                  onSurah: (surah) => _sync(() => _draft.pickToSurah(surah)),
                  validator: (value) =>
                      _draft.toAyahError(value, _fromAyah.text),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy || !canRecord ? null : _submit,
          child: Text(_draft.isEditing ? 'حفظ التعديل' : 'حفظ التسميع'),
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
      await deps.circles.saveRecitation(
        session: widget.session,
        studentId: widget.entry.studentId,
        studentUuid: widget.entry.studentUuid,
        type: _draft.type,
        fromSurah: _draft.fromSurah,
        fromAyah: int.parse(_fromAyah.text),
        toSurah: _draft.toSurah,
        toAyah: int.parse(_toAyah.text),
        grade: _draft.grade,
        juz: _draft.juz,
        notes: _notes.text.trim(),
        // المعرّف نفسه ⇒ الخادم يصحّح ولا يضيف ثانيةً (API.md §6).
        uuid: _draft.uuid,
      );

      deps.sync.syncNow();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _draft.isEditing
                ? 'صُفَّ التصحيح للمزامنة — الأسطر والنقاط يعيد الخادم حسابها.'
                : 'صُفَّ التسميع للمزامنة — الأسطر والنقاط يحسبها الخادم.',
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

/// طرفُ مدى: سورةٌ من قائمةٍ محصورة، وآيةٌ محدودةٌ بعدد آياتها.
class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.label,
    required this.surah,
    required this.surahs,
    required this.ayahController,
    required this.onSurah,
    required this.validator,
  });

  final String label;
  final int surah;
  final List<int> surahs;
  final TextEditingController ayahController;
  final ValueChanged<int> onSurah;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: surahs.contains(surah) ? surah : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: '$label سورة'),
            items: [
              for (final number in surahs)
                DropdownMenuItem(
                  value: number,
                  child: Text('$number. ${Quran.name(number)}'),
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
              labelText: '$label آية',
              helperText: 'من 1 إلى ${Quran.ayahs(surah)}',
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}
