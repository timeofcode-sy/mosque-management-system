import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../data/views.dart';
import '../di/app_scope.dart';

/// تسجيل التسميع وتصحيحه.
///
/// **لا أسطر ولا نقاط تُحسب هنا.** الخادم يحسبهما من المدى ويجمّدهما وقت
/// التسجيل ([API.md §6](../../../../../docs/API.md))، فحسابُهما في العميل يخلق
/// مصدرَ حقيقةٍ ثانياً يختلف عن الأول عند أول تعديلٍ في جدول الأسطر.
///
/// **والمدى يُختار من جزء لا من المصحف كلّه:** الأستاذ يسمّع داخل جزء، فاختيارُ
/// الجزء أولاً يقصر «من سورة» على سوره، و«إلى سورة» على ما بعد السورة المختارة
/// منه. وهو نفسه ما تفعله شاشة الجلسة في اللوحة، فلا يختلف النموذجان.
class RecitationScreen extends StatefulWidget {
  const RecitationScreen({
    super.key,
    required this.session,
    required this.entry,
    this.recitation,
  });

  final SessionView session;
  final RosterEntry entry;

  /// تسميعٌ مسجَّل يُفتح لتصحيحه — و`null` يعني تسميعاً جديداً.
  final RecitationEntry? recitation;

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fromAyah;
  late final TextEditingController _toAyah;
  late final TextEditingController _notes;

  late RecitationType _type;
  late RecitationGrade? _grade;
  late int _juz;
  late int _fromSurah;
  late int _toSurah;
  bool _busy = false;

  bool get _isEditing => widget.recitation != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.recitation;

    _type = existing?.type ?? RecitationType.hifz;
    _grade = existing?.grade ?? RecitationGrade.excellent;

    // الجزء المسجَّل يُحترم ما دام يسع طرفَي المدى؛ وإلا فُتح على جزء يسعهما، فلا
    // تُسقط القائمةُ المقيَّدة نصفَ مدىً سُجّل قبل هذا القيد أو من عميلٍ آخر.
    _fromSurah = existing?.fromSurah ?? Quran.surahsOfJuz(30).first;
    _toSurah = existing?.toSurah ?? _fromSurah;
    _juz = _juzFor(existing);

    _fromAyah = TextEditingController(text: '${existing?.fromAyah ?? 1}');
    _toAyah = TextEditingController(
      text: '${existing?.toAyah ?? Quran.ayahs(_toSurah)}',
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  int _juzFor(RecitationEntry? existing) {
    if (existing == null) {
      return 30;
    }

    final recorded = Quran.surahsOfJuz(existing.juz ?? 0);

    return recorded.contains(existing.fromSurah) &&
            recorded.contains(existing.toSurah)
        ? existing.juz!
        : Quran.juzSpanning(existing.fromSurah, existing.toSurah);
  }

  @override
  void dispose() {
    _fromAyah.dispose();
    _toAyah.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// تغيير الجزء يُعيد المدى إلى أوّل سورةٍ فيه كاملةً — فسورةُ الجزء السابق لم
  /// تعد في القائمة، وتركُها مختارةً يعني حفظَ مدىً لا يعرضه النموذج.
  void _pickJuz(int juz) {
    setState(() {
      _juz = juz;
      _fromSurah = Quran.surahsOfJuz(juz).first;
      _toSurah = _fromSurah;
      _fromAyah.text = '1';
      _toAyah.text = '${Quran.ayahs(_toSurah)}';
    });
  }

  /// «إلى سورة» لا تسبق «من سورة»: تغييرُ الأولى يجرّ الثانية معها.
  void _pickFromSurah(int surah) {
    setState(() {
      _fromSurah = surah;

      if (!Quran.surahsOfJuzFrom(_juz, surah).contains(_toSurah)) {
        _toSurah = surah;
        _toAyah.text = '${Quran.ayahs(_toSurah)}';
      }
    });
  }

  void _pickToSurah(int surah) {
    setState(() {
      _toSurah = surah;
      _toAyah.text = '${Quran.ayahs(surah)}';
    });
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
        studentId: widget.entry.studentId,
        studentUuid: widget.entry.studentUuid,
        type: _type,
        fromSurah: _fromSurah,
        fromAyah: int.parse(_fromAyah.text),
        toSurah: _toSurah,
        toAyah: int.parse(_toAyah.text),
        grade: _grade,
        juz: _juz,
        notes: _notes.text.trim(),
        // المعرّف نفسه ⇒ الخادم يصحّح ولا يضيف ثانيةً (API.md §6).
        uuid: widget.recitation?.uuid,
      );

      deps.sync.syncNow();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
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

  @override
  Widget build(BuildContext context) {
    final canRecord = widget.session.exists;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل تسميع' : 'تسجيل تسميع'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
            // الجزء أولاً: هو ما يقيّد القائمتين تحته.
            DropdownButtonFormField<int>(
              initialValue: _juz,
              decoration: const InputDecoration(labelText: 'الجزء'),
              items: [
                for (var juz = 1; juz <= 30; juz++)
                  DropdownMenuItem(value: juz, child: Text('الجزء $juz')),
              ],
              onChanged: (value) => value == null ? null : _pickJuz(value),
            ),
            const SizedBox(height: 12),
            _RangeRow(
              label: 'من',
              surah: _fromSurah,
              surahs: Quran.surahsOfJuz(_juz),
              ayahController: _fromAyah,
              onSurah: _pickFromSurah,
              validator: (value) => _ayahError(value, _fromSurah),
            ),
            const SizedBox(height: 12),
            _RangeRow(
              label: 'إلى',
              surah: _toSurah,
              surahs: Quran.surahsOfJuzFrom(_juz, _fromSurah),
              ayahController: _toAyah,
              onSurah: _pickToSurah,
              validator: _toAyahError,
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
              child: Text(_isEditing ? 'حفظ التعديل' : 'حفظ التسميع'),
            ),
          ],
        ),
      ),
    );
  }

  /// حدُّ رقم الآية بحدّ سورتها — يُتحقَّق محلياً لأن رفضه من الخادم يأتي بعد ساعات.
  static String? _ayahError(String? value, int surah) {
    final total = Quran.ayahs(surah);
    final ayah = int.tryParse((value ?? '').trim());

    return ayah == null || ayah < 1 || ayah > total ? 'بين 1 و$total' : null;
  }

  /// وداخل السورة الواحدة لا تسبق «إلى آية» «من آية» — وعبر سورتين لا معنى
  /// للمقارنة أصلاً: الترتيب تحسمه السورتان لا رقما الآيتين.
  String? _toAyahError(String? value) {
    final error = _ayahError(value, _toSurah);

    if (error != null || _fromSurah != _toSurah) {
      return error;
    }

    final from = int.tryParse(_fromAyah.text.trim());
    final to = int.tryParse((value ?? '').trim());

    return from != null && to != null && to < from
        ? 'لا تسبق «من آية» ($from)'
        : null;
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
