import 'package:flutter/material.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';
import '../widgets/adaptive.dart';
import '../widgets/form_section.dart';
import '../widgets/sync_bar.dart';

/// استمارةُ تسجيل الطالب كاملةً — ✅ م.6.5.
///
/// **وهي أوّلُ شاشةٍ في التطبيق تكتب صفّاً جديداً لا تصحّح قائماً**، وثلاثةُ
/// قراراتٍ فيها تستحقّ القراءة:
///
/// 1. **تُحفظ بضغطةٍ واحدة إلى الطابور** — لا تُقسَّم خطواتٍ ينتظر بينها ردَّ
///    الخادم. ومعرّفُ الطالب يولّده العميل، فتُصفّ الاستمارةُ وتسجيلُه في حلقةٍ
///    في **دفعةٍ واحدة**.
/// 2. **الصفاتُ والمحفوظاتُ والواصفاتُ تُقرأ من drift** — لا شيءَ منها مكتوبٌ في
///    Dart: الواصفةُ يعرّفها المشرف من غير كود، فالحقولُ تُرسَم من صفوفٍ لا من
///    ثوابتَ في الشيفرة.
/// 3. **الأعمدةُ الفارغة تُرسَل فارغة** — لا تُحذف. حفظُ استمارةٍ مُسحت منها
///    الملاحظاتُ يجب أن يمحوها فعلاً، وحذفُ المفتاح كان يبقيها.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.uuid});

  /// `null` لتسجيلٍ جديد.
  final String? uuid;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};

  StudentForm _form = const StudentForm();
  List<TraitOption> _traits = const [];
  List<CurriculumView> _curricula = const [];
  List<CustomFieldView> _fields = const [];
  List<CircleView> _circles = const [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final deps = AppScope.of(context);

    final form = widget.uuid == null
        ? const StudentForm()
        : await deps.students.loadStudentForm(widget.uuid!);

    final traits = await deps.students.loadTraits();
    final fields = await deps.students.loadStudentCustomFields();
    final curricula = await deps.catalog.loadCurricula();
    final circles = await deps.circles.loadCircles();

    if (!mounted) {
      return;
    }

    setState(() {
      _form = form ?? const StudentForm();
      _traits = traits;
      _fields = fields;
      _curricula = curricula;
      _circles = circles;
      _loading = false;
    });
  }

  TextEditingController _controller(String key, String? initial) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initial ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.uuid == null ? 'تسجيل طالب جديد' : 'تحرير الاستمارة',
        ),
        actions: [
          const PhoneSyncAction(),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            // الهاتف: «حفظ» وحدها بلا أيقونة، فيبقى العنوانُ مقروءاً بجانبها.
            child: context.isCompact && !_saving
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NzSpace.s4,
                      ),
                    ),
                    onPressed: _save,
                    child: const Text('حفظ'),
                  )
                : FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const NzIcon(NzIcons.save, size: 18),
                    label: const Text('حفظ'),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(context.gutter(24)),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ErrorBanner(message: _error!),
              ),
            FormSection(
              title: 'بيانات التسجيل',
              children: [
                _text(
                  'registration_no',
                  'رقم المعرف (البطاقة)',
                  _form.registrationNo,
                  onChanged: (value) =>
                      _form = _form.copyWith(registrationNo: value),
                ),
                _date(
                  label: 'تاريخ التسجيل',
                  value: _form.registrationDate,
                  onChanged: (value) => setState(
                    () => _form = _form.copyWith(registrationDate: value),
                  ),
                ),
                _text(
                  'registration_date_hijri',
                  'التاريخ الهجري',
                  _form.registrationDateHijri,
                  hint: '1447/03/12',
                  onChanged: (value) =>
                      _form = _form.copyWith(registrationDateHijri: value),
                ),
                _dropdown(
                  label: 'حالة الطالب',
                  value: _form.status,
                  options: const {
                    'active': 'فعّال',
                    'graduated': 'متخرّج',
                    'suspended': 'موقوف',
                    'left': 'منقطع',
                  },
                  onChanged: (value) =>
                      setState(() => _form = _form.copyWith(status: value)),
                ),
              ],
            ),
            FormSection(
              title: 'البيانات الشخصية',
              children: [
                _text(
                  'first_name',
                  'اسم الطالب',
                  _form.firstName,
                  required: true,
                  onChanged: (value) =>
                      _form = _form.copyWith(firstName: value ?? ''),
                ),
                _text(
                  'father_name',
                  'اسم الأب',
                  _form.fatherName,
                  required: true,
                  onChanged: (value) {
                    _form = _form.copyWith(fatherName: value ?? '');
                    _syncFatherFullName();
                  },
                ),
                _text(
                  'family_name',
                  'اسم العائلة',
                  _form.familyName,
                  required: true,
                  onChanged: (value) {
                    _form = _form.copyWith(familyName: value ?? '');
                    _syncFatherFullName();
                  },
                ),
                _date(
                  label: 'تاريخ الولادة',
                  value: _form.birthDate,
                  onChanged: (value) =>
                      setState(() => _form = _form.copyWith(birthDate: value)),
                ),
                _text(
                  'birth_place',
                  'مكان الولادة',
                  _form.birthPlace,
                  onChanged: (value) =>
                      _form = _form.copyWith(birthPlace: value),
                ),
                _dropdown(
                  label: 'الجنس',
                  value: _form.gender,
                  options: const {'male': 'ذكر', 'female': 'أنثى'},
                  allowEmpty: true,
                  onChanged: (value) =>
                      setState(() => _form = _form.copyWith(gender: value)),
                ),
                _text(
                  'national_id',
                  'الرقم الوطني',
                  _form.nationalId,
                  onChanged: (value) =>
                      _form = _form.copyWith(nationalId: value),
                ),
                _text(
                  'grade_level',
                  'الصف الدراسي',
                  _form.gradeLevel,
                  onChanged: (value) =>
                      _form = _form.copyWith(gradeLevel: value),
                ),
                _text(
                  'student_job',
                  'عمل الطالب أو مهنته',
                  _form.studentJob,
                  onChanged: (value) =>
                      _form = _form.copyWith(studentJob: value),
                ),
                _text(
                  'phone',
                  'جوّال الطالب',
                  _form.phone,
                  onChanged: (value) => _form = _form.copyWith(phone: value),
                ),
                _text(
                  'permanent_address',
                  'العنوان الأساسي',
                  _form.permanentAddress,
                  onChanged: (value) =>
                      _form = _form.copyWith(permanentAddress: value),
                ),
                _text(
                  'current_address',
                  'العنوان الحالي',
                  _form.currentAddress,
                  onChanged: (value) =>
                      _form = _form.copyWith(currentAddress: value),
                ),
              ],
            ),
            FormSection(
              title: 'بيانات الأب والأم',
              // ولياّن لا ستةُ أعمدة في صفّ الطالب: الوليُّ قد يتابع أكثر من
              // ابنٍ في المعهد، ويملك حساباً واحداً في تطبيق الأهل.
              children: [
                // لا يُكتب: اسمُ الأب متبوعاً بالكنية، ويُعدَّل من البيانات الشخصية.
                _text(
                  'father_full_name',
                  'اسم الأب الكامل',
                  _form.fatherFullName,
                  readOnly: true,
                  onChanged: (_) {},
                ),
                _text(
                  'father_occupation',
                  'عمل الأب',
                  _form.father.occupation,
                  onChanged: (value) => _form = _form.copyWith(
                    father: _form.father.copyWith(occupation: value),
                  ),
                ),
                _text(
                  'father_phone',
                  'جوّال الأب',
                  _form.father.phone,
                  onChanged: (value) => _form = _form.copyWith(
                    father: _form.father.copyWith(phone: value),
                  ),
                ),
                _text(
                  'mother_first_name',
                  'اسم الأم',
                  _form.mother.firstName,
                  onChanged: (value) => _form = _form.copyWith(
                    mother: _form.mother.copyWith(firstName: value),
                  ),
                ),
                _text(
                  'mother_family_name',
                  'كنية الأم',
                  _form.mother.familyName,
                  onChanged: (value) => _form = _form.copyWith(
                    mother: _form.mother.copyWith(familyName: value),
                  ),
                ),
                _text(
                  'mother_occupation',
                  'عمل الأم',
                  _form.mother.occupation,
                  onChanged: (value) => _form = _form.copyWith(
                    mother: _form.mother.copyWith(occupation: value),
                  ),
                ),
                _text(
                  'mother_phone',
                  'جوّال الأم',
                  _form.mother.phone,
                  onChanged: (value) => _form = _form.copyWith(
                    mother: _form.mother.copyWith(phone: value),
                  ),
                ),
                _text(
                  'family_members_count',
                  'عدد أفراد العائلة',
                  _form.familyMembersCount?.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _form = _form.copyWith(
                    familyMembersCount: value == null || value.isEmpty
                        ? null
                        : int.tryParse(value),
                  ),
                ),
              ],
            ),
            FormSection(
              title: 'الوضع الصحي',
              children: [
                _text(
                  'student_health_status',
                  'الوضع الصحي للطالب',
                  _form.studentHealthStatus,
                  lines: 3,
                  onChanged: (value) =>
                      _form = _form.copyWith(studentHealthStatus: value),
                ),
                _text(
                  'family_health_status',
                  'الوضع الصحي للعائلة',
                  _form.familyHealthStatus,
                  lines: 3,
                  onChanged: (value) =>
                      _form = _form.copyWith(familyHealthStatus: value),
                ),
              ],
            ),
            if (_traits.isNotEmpty)
              FormSection(
                title: 'الصفات الشخصية والسلوكية',
                child: _Choices(
                  options: {
                    for (final trait in _traits) trait.uuid: trait.name,
                  },
                  selected: _form.traitUuids,
                  onChanged: (selected) => setState(
                    () => _form = _form.copyWith(traitUuids: selected),
                  ),
                ),
              ),
            for (final curriculum in _curricula)
              if (curriculum.items.isNotEmpty)
                FormSection(
                  title: 'المحفوظ من ${curriculum.name}',
                  child: _Choices(
                    options: {
                      for (final item in curriculum.items) item.uuid: item.name,
                    },
                    selected: _form.memorizedItemUuids,
                    onChanged: (selected) => setState(
                      () =>
                          _form = _form.copyWith(memorizedItemUuids: selected),
                    ),
                  ),
                ),
            if (_fields.isNotEmpty)
              FormSection(
                title: 'واصفات المعهد',
                children: [for (final field in _fields) _customField(field)],
              ),
            FormSection(
              title: 'التسجيل في حلقة',
              children: [
                _dropdown(
                  label: 'الحلقة في الدورة الجارية',
                  value: _form.courseCircleUuid,
                  options: {
                    for (final circle in _circles)
                      circle.uuid: '${circle.circleName} — ${circle.shiftName}',
                  },
                  allowEmpty: true,
                  emptyLabel: 'بلا تسجيل الآن',
                  onChanged: (value) => setState(
                    () => _form = _form.copyWith(courseCircleUuid: value),
                  ),
                ),
              ],
            ),
            FormSection(
              title: 'ملاحظات',
              children: [
                _text(
                  'notes',
                  'ملاحظات عامة',
                  _form.notes,
                  lines: 3,
                  onChanged: (value) => _form = _form.copyWith(notes: value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ الحقول

  Widget _text(
    String key,
    String label,
    String? initial, {
    bool required = false,
    int lines = 1,
    String? hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: lines > 1 ? 640 : 300,
      child: TextFormField(
        controller: _controller(key, initial),
        maxLines: lines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: readOnly
              ? const NzIcon(NzIcons.lockClosed, size: 18)
              : null,
        ),
        validator: required
            ? (value) => (value ?? '').trim().isEmpty ? 'حقلٌ مطلوب' : null
            : null,
        // القيمةُ الفارغة تُمرَّر `null` لا تُترك على ما كانت: مسحُ حقلٍ في
        // الاستمارة يجب أن يمحوَه فعلاً على الخادم.
        onChanged: (value) => onChanged(value.trim().isEmpty ? null : value),
      ),
    );
  }

  Widget _date({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return SizedBox(
      width: 300,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(1940),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );

          if (picked != null) {
            onChanged(picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: value == null
                ? const NzIcon(NzIcons.calendar, size: 18)
                : IconButton(
                    icon: const NzIcon(NzIcons.close, size: 18),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(value == null ? '—' : _isoDate(value)),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required Map<String, String> options,
    bool allowEmpty = false,
    String emptyLabel = 'بلا تحديد',
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 300,
      child: DropdownButtonFormField<String?>(
        // قيمةٌ لا وجودَ لها في القائمة تُعامَل فارغةً: لقطةٌ قديمة أو حلقةٌ
        // حُذفت من الدورة لا يجوز أن تُسقط الشاشة.
        initialValue: options.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          if (allowEmpty)
            DropdownMenuItem<String?>(value: null, child: Text(emptyLabel)),
          for (final entry in options.entries)
            DropdownMenuItem<String?>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  /// حقلٌ لواصفةٍ عرّفها المشرف — نوعُه يأتي من الصفّ لا من الشيفرة.
  Widget _customField(CustomFieldView field) {
    if (field.type == 'select' && field.options.isNotEmpty) {
      return _dropdown(
        label: field.label,
        value: _form.customFields[field.uuid],
        options: {for (final option in field.options) option: option},
        allowEmpty: !field.isRequired,
        onChanged: (value) =>
            setState(() => _setCustomField(field.uuid, value)),
      );
    }

    if (field.type == 'boolean') {
      return SizedBox(
        width: 300,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: _form.customFields[field.uuid] == 'true',
          onChanged: (value) =>
              setState(() => _setCustomField(field.uuid, value.toString())),
        ),
      );
    }

    return _text(
      'custom_${field.uuid}',
      field.isRequired ? '${field.label} *' : field.label,
      _form.customFields[field.uuid],
      lines: field.type == 'textarea' ? 3 : 1,
      keyboardType: field.type == 'number'
          ? TextInputType.number
          : TextInputType.text,
      onChanged: (value) => _setCustomField(field.uuid, value),
    );
  }

  void _syncFatherFullName() {
    _controller('father_full_name', null).text = _form.fatherFullName;
  }

  void _setCustomField(String uuid, String? value) {
    final next = Map<String, String>.from(_form.customFields);

    if (value == null || value.isEmpty) {
      next.remove(uuid);
    } else {
      next[uuid] = value;
    }

    _form = _form.copyWith(customFields: next);
  }

  // ------------------------------------------------------------- الحفظ

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final students = AppScope.of(context).students;

    try {
      final sibling = await _askAboutSiblings(students);

      if (sibling == null) {
        // أُغلق السؤال دون جواب: لا حفظَ حتى يجيب المشرف.
        if (mounted) {
          setState(() => _saving = false);
        }

        return;
      }

      await students.saveStudent(_form, sibling: sibling.family);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = messageFor(error);
      });

      return;
    }

    if (!mounted) {
      return;
    }

    // لا انتظارَ لردّ الخادم: العمليةُ في الطابور، وشريطُ المزامنة يعرض ما بقي
    // منه — وهو التمييزُ الذي بُني عليه التطبيق كلُّه.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('حُفظت الاستمارة وصُفَّت للمزامنة.')),
    );

    Navigator.of(context).pop();
  }

  /// يسأل عن كلّ عائلةٍ مسجَّلةٍ يطابق أبواها ما في الاستمارة: «هل الطالب فلان هو أخ
  /// الطالب فلان؟». الجوابُ «نعم» يربطه بوليّي أمرها على الخادم، و«لا» ينتقل إلى
  /// العائلة التالية، فإن نفدت أُنشئ له وليّا أمر جديدان. ويعود `null` إن أُلغي.
  Future<_SiblingAnswer?> _askAboutSiblings(StudentRepository students) async {
    final families = await students.findSiblingFamilies(
      fatherFullName: _form.fatherFullName,
      motherFullName: _form.mother.fullName,
      exceptStudentUuid: _form.uuid,
    );

    for (final family in families) {
      if (!mounted) {
        return null;
      }

      final answer = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('أخٌ مسجَّل؟'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(
                  _siblingQuestion(family),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'اسم الأب الكامل واسم الأم وكنيتها تطابق طالباً مسجَّلاً. '
                  'إن كانا أخوين رُبط الطالب بوليّي الأمر أنفسهما فيتابع '
                  'حسابُهما الأبناءَ معاً، وإلا أُنشئ له وليّا أمر جديدان.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('لا، ليسا أخوين'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('نعم، أخوان'),
            ),
          ],
        ),
      );

      if (answer == null) {
        return null;
      }

      if (answer) {
        return _SiblingAnswer(family);
      }
    }

    return const _SiblingAnswer(null);
  }

  /// «هل الطالب فلان هو أخ الطالب فلان؟» — بصيغة المؤنّث حيث تلزم.
  String _siblingQuestion(SiblingFamily family) {
    final others = family.students
        .map(
          (sibling) =>
              '${sibling.gender == 'female' ? 'الطالبة' : 'الطالب'} ${sibling.fullName}',
        )
        .join(' و');

    return _form.gender == 'female'
        ? 'هل الطالبة ${_form.fullName} هي أخت $others؟'
        : 'هل الطالب ${_form.fullName} هو أخ $others؟';
  }

  static String _isoDate(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

/// جوابُ سؤال الأخوّة: عائلةُ الأخ إن أُجيب «نعم»، أو `null` إن لم يكن أخاً لأحد.
class _SiblingAnswer {
  const _SiblingAnswer(this.family);

  final SiblingFamily? family;
}

/// اختيارٌ متعدّد بمربّعات — الصفاتُ والمحفوظات.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          FilterChip(
            label: Text(entry.value),
            selected: selected.contains(entry.key),
            onSelected: (value) {
              final next = Set<String>.from(selected);
              value ? next.add(entry.key) : next.remove(entry.key);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(NzRadius.sm),
      ),
      child: Row(
        spacing: 8,
        children: [
          NzIcon(
            NzIcons.exclamationCircle,
            color: scheme.onErrorContainer,
            size: 20,
          ),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
