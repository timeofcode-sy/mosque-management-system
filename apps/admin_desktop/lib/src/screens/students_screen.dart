import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/adaptive.dart';
import 'student_form_screen.dart';
import 'student_profile_screen.dart';
import 'transfer_dialog.dart';

/// كشفُ طلاب المعهد — ✅ م.6.5، وهو مدخلُ الاستمارة والتسجيل والنقل.
///
/// **يُفتح والشبكةُ مقطوعة**: الصفوفُ من drift، والكتابةُ طابورٌ. وهو الفرقُ
/// العملي بين هذا السطح واللوحة — المشرفُ يسجّل طالباً وصل مع أبيه إلى المسجد
/// ولا شبكةَ في المكان.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// التصفية — والحالةُ الافتراضية **الفعّالون وحدهم**: كشفٌ يخلط المتخرّجين
  /// والمنقطعين بالحاضرين يطول بلا فائدةٍ يومية.
  StudentFilters _filters = const StudentFilters();

  /// واصفاتُ الطالب ذات الخيارات (السكن…) — مادةُ التصفية المتقدّمة.
  List<CustomFieldView> _fields = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_fields.isEmpty) {
      AppScope.of(context).students.loadStudentCustomFields().then((fields) {
        if (mounted) {
          setState(() {
            _fields = [
              for (final field in fields)
                if (field.options.isNotEmpty &&
                    (field.type == 'select' || field.type == 'multi_select'))
                  field,
            ];
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final canManage = deps.session.can('students.manage');
    final compact = context.isCompact;

    return Scaffold(
      // على الهاتف زرٌّ عائمٌ فوق الشريط السفلي، حيث يصل إليه الإبهام.
      floatingActionButton: canManage && compact
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const NzIcon(NzIcons.userPlus),
              label: const Text('تسجيل طالب'),
            )
          : null,
      appBar: AppBar(
        title: const Text('طلاب المعهد'),
        actions: [
          // ما لا يملكه المستخدم لا يظهر أصلاً — لا زرَّ معطَّلاً ولا رسالةَ رفض
          // عند الضغط (نفسُ قاعدة القائمة الجانبية في م.6.3).
          if (canManage && !compact)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: FilledButton.icon(
                onPressed: () => _openForm(context),
                icon: const NzIcon(NzIcons.userPlus, size: 18),
                label: const Text('تسجيل طالب'),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<StudentListEntry>>(
        stream: deps.students.watchStudents(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;

          if (all.isEmpty) {
            return EmptyState(
              message:
                  'لا طلاب في هذا المعهد بعد.\n'
                  'سجّل أوّلَ طالب، أو زامِن الجهازَ إن كان المعهد قائماً.',
              icon: NzIcons.certificate,
              onRetry: deps.sync.syncNow,
            );
          }

          // التصفيةُ أولاً، ثم البحثُ العربيّ المتسامح مرتَّباً بالأقرب (ArabicSearch).
          final found = ArabicSearch.rank(
            all.where(_filters.accepts).toList(),
            _query,
            (student) => student.searchable,
          );
          final students = found.items;

          return Column(
            children: [
              _Filters(
                controller: _search,
                filters: _filters,
                circles: _sorted(all.map((s) => s.circleName)),
                onQuery: (value) => setState(() => _query = value.trim()),
                onFilters: (filters) => setState(() => _filters = filters),
                onAdvanced: () => _openAdvanced(context, all),
                total: all.length,
                shown: students.length,
              ),
              _Chips(
                filters: _filters,
                fields: _fields,
                onChanged: (filters) => setState(() => _filters = filters),
              ),
              if (found.approximate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'لا تطابقَ تامّاً لـ«$_query» — هذه أقرب النتائج.',
                      style: NzType.caption.copyWith(color: context.nz.warning),
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: students.isEmpty
                    ? const EmptyState(
                        message: 'لا طالب يطابق البحث.',
                        icon: NzIcons.search,
                      )
                    : _StudentTable(
                        resetKey: '$_query|${_filters.hashCode}',
                        students: students,
                        canManage: canManage,
                        canTransfer: deps.session.can('transfers.manage'),
                        onOpen: (student) => _openProfile(context, student),
                        onEdit: (student) =>
                            _openForm(context, uuid: student.uuid),
                        onTransfer: (student) =>
                            _openTransfer(context, student),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<String> _sorted(Iterable<String?> values) =>
      (values
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort());

  Future<void> _openAdvanced(
    BuildContext context,
    List<StudentListEntry> all,
  ) async {
    final panel = _AdvancedFilters(
      initial: _filters,
      fields: _fields,
      grades: _sorted(all.map((s) => s.gradeLevel)),
      years:
          (all.map((s) => s.birthDate?.year).whereType<int>().toSet().toList()
            ..sort((a, b) => b.compareTo(a))),
    );

    final result = context.isCompact
        ? await showModalBottomSheet<StudentFilters>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => panel,
          )
        : await showDialog<StudentFilters>(
            context: context,
            builder: (_) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: panel,
              ),
            ),
          );

    if (result != null && mounted) {
      setState(() => _filters = result);
    }
  }

  Future<void> _openForm(BuildContext context, {String? uuid}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StudentFormScreen(uuid: uuid)),
    );
  }

  void _openProfile(BuildContext context, StudentListEntry student) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentProfileScreen(studentId: student.id),
      ),
    );
  }

  Future<void> _openTransfer(
    BuildContext context,
    StudentListEntry student,
  ) async {
    await showTransferDialog(context, student: student);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.controller,
    required this.filters,
    required this.circles,
    required this.onQuery,
    required this.onFilters,
    required this.onAdvanced,
    required this.total,
    required this.shown,
  });

  final TextEditingController controller;
  final StudentFilters filters;
  final List<String> circles;
  final ValueChanged<String> onQuery;
  final ValueChanged<StudentFilters> onFilters;
  final VoidCallback onAdvanced;
  final int total;
  final int shown;

  static const _statuses = {
    'active': 'الفعّالون',
    'graduated': 'المتخرّجون',
    'suspended': 'الموقوفون',
    'left': 'المنقطعون',
    'all': 'الكل',
  };

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: controller,
      onChanged: onQuery,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const NzIcon(NzIcons.search, size: 20),
        hintText: context.isCompact
            ? 'الاسم أو الوالد أو البطاقة أو الجوّال'
            : 'ابحث بالاسم أو اسم الوالد أو رقم البطاقة أو الجوّال أو الحلقة',
        border: const OutlineInputBorder(),
      ),
    );
    final status = DropdownButtonFormField<String>(
      initialValue: filters.status,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'الحالة',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final entry in _statuses.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (value) =>
          onFilters(filters.copyWith(status: value ?? 'active')),
    );
    final circle = DropdownButtonFormField<String?>(
      // مفتاحٌ بالقيمة: إزالةُ الشارة تعيد القائمةَ إلى «كل الحلقات».
      key: ValueKey('circle-${filters.circle}'),
      initialValue: filters.circle,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'الحلقة',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(child: Text('كل الحلقات')),
        const DropdownMenuItem(
          value: StudentFilters.noCircle,
          child: Text('بلا حلقة'),
        ),
        for (final name in circles)
          DropdownMenuItem(
            value: name,
            child: Text(name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => onFilters(filters.copyWith(circle: value)),
    );
    final advancedCount = filters.advancedCount;
    final advanced = Badge(
      isLabelVisible: advancedCount > 0,
      label: Text('$advancedCount'),
      child: OutlinedButton.icon(
        onPressed: onAdvanced,
        icon: const NzIcon(NzIcons.funnel, size: 18),
        label: const Text('تصفية متقدّمة'),
      ),
    );
    final count = Text(
      shown == total ? '$total طالباً' : '$shown من $total',
      style: Theme.of(context).textTheme.labelMedium,
    );

    // الهاتف: البحثُ بعرض الشاشة، والحالةُ والحلقةُ تحته، ثم التصفيةُ والعدد.
    if (context.isCompact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          spacing: 12,
          children: [
            search,
            Row(
              spacing: 12,
              children: [
                Expanded(child: status),
                Expanded(child: circle),
              ],
            ),
            Row(children: [advanced, const Spacer(), count]),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        spacing: 12,
        children: [
          Expanded(flex: 4, child: search),
          Expanded(flex: 2, child: status),
          Expanded(flex: 2, child: circle),
          advanced,
          count,
        ],
      ),
    );
  }
}

/// التصفياتُ المفعّلة شاراتٍ تُزال واحدةً واحدة.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.filters,
    required this.fields,
    required this.onChanged,
  });

  final StudentFilters filters;
  final List<CustomFieldView> fields;
  final ValueChanged<StudentFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = filters;
    final chips = <(String, StudentFilters)>[
      if (f.circle == StudentFilters.noCircle)
        ('بلا حلقة', f.copyWith(circle: null))
      else if (f.circle != null)
        ('حلقة ${f.circle}', f.copyWith(circle: null)),
      if (f.father != null)
        (
          f.father == 'deceased' ? 'الأب متوفى' : 'الأب على قيد الحياة',
          f.copyWith(father: null),
        ),
      for (final MapEntry(key: uuid, value: value) in f.fields.entries)
        (
          '${fields.where((field) => field.uuid == uuid).firstOrNull?.label ?? ''}: $value',
          f.copyWith(fields: {...f.fields}..remove(uuid)),
        ),
      if (f.address.trim().isNotEmpty)
        ('العنوان: ${f.address.trim()}', f.copyWith(address: '')),
      if (f.grade != null) ('الصف: ${f.grade}', f.copyWith(grade: null)),
      if (f.gender != null)
        (f.gender == 'female' ? 'أنثى' : 'ذكر', f.copyWith(gender: null)),
      if (f.bornFrom != null || f.bornTo != null)
        (
          'المواليد: ${f.bornFrom ?? '…'} – ${f.bornTo ?? '…'}',
          f.copyWith(bornFrom: null, bornTo: null),
        ),
      if (f.juzMin > 0) ('حافظ ${f.juzMin} أجزاء فأكثر', f.copyWith(juzMin: 0)),
    ];

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (label, without) in chips)
              InputChip(
                label: Text(label),
                onDeleted: () => onChanged(without),
                visualDensity: VisualDensity.compact,
              ),
            TextButton.icon(
              onPressed: () =>
                  onChanged(StudentFilters(status: filters.status)),
              icon: const NzIcon(NzIcons.close, size: 16),
              label: const Text('مسح التصفية'),
            ),
          ],
        ),
      ),
    );
  }
}

/// لوحةُ التصفية المتقدّمة: تُحرَّر نسخةً، ولا تُطبَّق إلا بـ«تطبيق».
class _AdvancedFilters extends StatefulWidget {
  const _AdvancedFilters({
    required this.initial,
    required this.fields,
    required this.grades,
    required this.years,
  });

  final StudentFilters initial;
  final List<CustomFieldView> fields;
  final List<String> grades;
  final List<int> years;

  @override
  State<_AdvancedFilters> createState() => _AdvancedFiltersState();
}

class _AdvancedFiltersState extends State<_AdvancedFilters> {
  late StudentFilters _draft = widget.initial;
  late final _address = TextEditingController(text: widget.initial.address);
  late final _juz = TextEditingController(
    text: widget.initial.juzMin > 0 ? '${widget.initial.juzMin}' : '',
  );

  @override
  void dispose() {
    _address.dispose();
    _juz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dropdown<T>({
      required String label,
      required T? value,
      required Map<T?, String> options,
      required ValueChanged<T?> onChanged,
    }) {
      return SizedBox(
        width: 280,
        child: DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final MapEntry(key: key, value: text) in options.entries)
              DropdownMenuItem(value: key, child: Text(text)),
          ],
          onChanged: onChanged,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text('تصفية متقدّمة', style: Theme.of(context).textTheme.titleLarge),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              dropdown<String>(
                label: 'الأب',
                value: _draft.father,
                options: const {
                  null: 'الكل',
                  'deceased': 'متوفى',
                  'alive': 'على قيد الحياة',
                },
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(father: v)),
              ),
              for (final field in widget.fields)
                dropdown<String>(
                  label: field.label,
                  value: _draft.fields[field.uuid],
                  options: {null: 'الكل', for (final o in field.options) o: o},
                  onChanged: (v) => setState(() {
                    final fields = {..._draft.fields}..remove(field.uuid);
                    _draft = _draft.copyWith(
                      fields: v == null ? fields : {...fields, field.uuid: v},
                    );
                  }),
                ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'العنوان يحوي',
                    hintText: 'مثلاً: زملكا، العسقلاني',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => _draft = _draft.copyWith(address: v),
                ),
              ),
              dropdown<String>(
                label: 'الصف',
                value: _draft.grade,
                options: {
                  null: 'كل الصفوف',
                  for (final g in widget.grades) g: g,
                },
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(grade: v)),
              ),
              dropdown<String>(
                label: 'الجنس',
                value: _draft.gender,
                options: const {null: 'الكل', 'male': 'ذكر', 'female': 'أنثى'},
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(gender: v)),
              ),
              dropdown<int>(
                label: 'مواليد من',
                value: _draft.bornFrom,
                options: {null: '—', for (final y in widget.years) y: '$y'},
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(bornFrom: v)),
              ),
              dropdown<int>(
                label: 'مواليد إلى',
                value: _draft.bornTo,
                options: {null: '—', for (final y in widget.years) y: '$y'},
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(bornTo: v)),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _juz,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'الأجزاء المحفوظة (على الأقل)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      _draft = _draft.copyWith(juzMin: int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  StudentFilters(status: _draft.status, circle: _draft.circle),
                ),
                child: const Text('مسح'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_draft),
                child: const Text('تطبيق'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// جدولٌ من أعمدة لا بطاقاتٌ — نافذةُ مكتبٍ تعرض ثلاثين صفّاً في شاشةٍ واحدة،
/// وهو الفرقُ الذي منع رفعَ الشاشات إلى الحزمة في م.6.4.
class _StudentTable extends StatelessWidget {
  const _StudentTable({
    required this.students,
    required this.canManage,
    required this.canTransfer,
    required this.onOpen,
    required this.onEdit,
    required this.onTransfer,
    this.resetKey,
  });

  final Object? resetKey;
  final List<StudentListEntry> students;
  final bool canManage;
  final bool canTransfer;
  final ValueChanged<StudentListEntry> onOpen;
  final ValueChanged<StudentListEntry> onEdit;
  final ValueChanged<StudentListEntry> onTransfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // الهاتف: خمسةُ أعمدةٍ لا يسعها 360px — صفٌّ بسطرين: الاسمُ ثم البطاقةُ
    // والحلقةُ والجوّال، والأفعالُ في قائمة. والهامشُ السفليّ يترك الزرَّ العائم
    // فوق آخر صفّ لا عليه.
    if (context.isCompact) {
      return PagedList<StudentListEntry>(
        items: students,
        resetKey: resetKey,
        onTap: onOpen,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        rowPadding: const EdgeInsetsDirectional.fromSTEB(16, 10, 4, 10),
        itemBuilder: (context, student) => _CompactRow(
          student: student,
          actions: [
            if (canManage)
              RowAction(
                icon: NzIcons.edit,
                label: 'تحرير الاستمارة',
                onPressed: () => onEdit(student),
              ),
            if (canTransfer)
              RowAction(
                icon: NzIcons.review,
                label: 'نقل إلى حلقة أخرى',
                onPressed: () => onTransfer(student),
              ),
          ],
        ),
      );
    }

    // قائمةٌ مرقَّمة بنمط الجدول (PagedList): بطاقةٌ بحدّ وهوامش 20/12 ورأسٌ على sunken وترقيمٌ تحتها.
    // مفتاحُ الإعادة هو البحث والحالة فيعود المشرفُ إلى الصفحة الأولى بتغيّر المرشّح.
    return PagedList<StudentListEntry>(
      items: students,
      resetKey: resetKey,
      onTap: onOpen,
      header: const _Row(
        registration: Text('رقم البطاقة'),
        name: Text('الاسم'),
        circle: Text('الحلقة'),
        phone: Text('الجوّال'),
        actions: SizedBox.shrink(),
      ),
      itemBuilder: (context, student) => _Row(
        registration: Text(student.registrationNo ?? '—'),
        name: Row(
          spacing: 8,
          children: [
            Flexible(child: Text(student.fullName)),
            // وسمُ «لم تصل بعد» — وإلا ظنّ المشرف أن حفظَه ضاع فأعاده.
            if (student.pending)
              Tooltip(
                message: 'كتابةٌ لم تصل الخادمَ بعد',
                child: NzIcon(
                  NzIcons.upload,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        circle: Text(student.circleName ?? 'بلا حلقة'),
        phone: Text(student.phone ?? '—'),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (canManage)
              IconButton(
                tooltip: 'تحرير الاستمارة',
                icon: const NzIcon(NzIcons.edit, size: 18),
                onPressed: () => onEdit(student),
              ),
            if (canTransfer)
              IconButton(
                tooltip: 'نقل إلى حلقة أخرى',
                icon: const NzIcon(NzIcons.review, size: 18),
                onPressed: () => onTransfer(student),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.student, required this.actions});

  final StudentListEntry student;
  final List<RowAction> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Row(
                spacing: 6,
                children: [
                  Flexible(
                    child: Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NzType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (student.pending)
                    Tooltip(
                      message: 'كتابةٌ لم تصل الخادمَ بعد',
                      child: NzIcon(NzIcons.upload, size: 16, color: c.primary),
                    ),
                ],
              ),
              Text(
                [
                  student.registrationNo ?? '—',
                  student.circleName ?? 'بلا حلقة',
                  // الجوّالُ معزولٌ يساراً-يميناً: «0944 123 457» لا تنقلب
                  // مقاطعُه في سطرٍ عربي.
                  if (student.phone case final phone?) '\u2066$phone\u2069',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NzType.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        RowActionsMenu(actions: actions),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.registration,
    required this.name,
    required this.circle,
    required this.phone,
    required this.actions,
  });

  final Widget registration;
  final Widget name;
  final Widget circle;
  final Widget phone;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 120, child: registration),
        Expanded(flex: 4, child: name),
        Expanded(flex: 3, child: circle),
        Expanded(flex: 2, child: phone),
        SizedBox(width: 104, child: actions),
      ],
    );
  }
}
