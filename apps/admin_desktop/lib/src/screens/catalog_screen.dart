import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/connected_action.dart';

/// بنيةُ الدورة: الدوراتُ والدواماتُ والحلقات — ✅ م.6.5.
///
/// **الشاشةُ الوحيدة في التطبيق التي تكتب متّصلةً** ([API.md §3.10.1]):
/// هي بنيةٌ يُبنى عليها لا حدثٌ يُسجَّل — الجلسةُ والتسجيلُ والتفقّد تُعلَّق كلُّها
/// على `course_circles`، ولو صُفَّت أوف-لاين لَصفَّ الجهازُ فوقها عشراتِ العمليات
/// ثم رُفض أصلُها فسقط ما فوقه. وتُهيَّأ مرّةً في الفصل من مكتب.
///
/// **والقراءةُ من drift** رغم ذلك: الجداولُ الثلاثة تُزامَن، فما يُكتب هنا يعود
/// في `sync/pull` — ولذلك لا `GET` في `CatalogController` أصلاً. وثمنُه أن
/// الأثرَ لا يظهر فوراً، فكلُّ كتابةٍ تُتبَع بمزامنةٍ فورية.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;

    // الألسنةُ تُرشَّح بالصلاحيات كما تُرشَّح الأبواب: من يملك `shifts.manage`
    // ولا يملك `courses.manage` يرى الدوامات وحدها.
    final tabs = <(String, Widget)>[
      if (session.can('courses.manage')) ('الدورات', const _CoursesTab()),
      if (session.can('shifts.manage')) ('الدوامات', const _ShiftsTab()),
      if (session.can('circles.manage')) ('الحلقات', const _CirclesTab()),
    ];

    if (tabs.isEmpty) {
      return const Scaffold(
        body: EmptyState(
          message: 'لا تملك صلاحيةَ تهيئةِ بنية الدورة.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الدورات والدوامات والحلقات'),
          bottom: TabBar(
            tabs: [for (final tab in tabs) Tab(text: tab.$1)],
          ),
        ),
        body: TabBarView(children: [for (final tab in tabs) tab.$2]),
      ),
    );
  }
}

// ------------------------------------------------------------------ الدورات

class _CoursesTab extends StatelessWidget {
  const _CoursesTab();

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return _TabBody<CourseView>(
      stream: deps.catalog.watchCourses(),
      emptyMessage: 'لا دورات في هذا المعهد بعد.\nأنشئ الدورة الأولى لتبدأ الحلقات.',
      emptyIcon: Icons.calendar_month_outlined,
      onCreate: () => _edit(context),
      createLabel: 'دورة جديدة',
      itemBuilder: (context, course) => ListTile(
        title: Row(
          spacing: 8,
          children: [
            Text(course.name),
            if (course.isCurrent)
              const Chip(
                label: Text('الجارية', style: TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text(
          '${_date(course.startsOn)}'
          '${course.endsOn == null ? '' : ' ← ${_date(course.endsOn!)}'}'
          ' · ${course.statusLabel}'
          ' · ${course.shiftsCount} دوام · ${course.circlesCount} حلقة',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // «اجعلها الجارية» فعلٌ مستقلّ لأنه يُنزل الجاريةَ السابقة ويمسّ كلَّ
            // شاشةٍ تشغيلية — فلا يُدسّ داخل زرِّ الحفظ.
            if (!course.isCurrent)
              TextButton(
                onPressed: () => _activate(context, course),
                child: const Text('اجعلها الجارية'),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _edit(context, course),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activate(BuildContext context, CourseView course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير الدورة الجارية'),
        content: Text(
          'ستصير «${course.name}» الدورةَ الجارية، وتنزل الحاليةُ عن موضعها.\n'
          'وهذا يغيّر ما تعرضه شاشاتُ التفقّد والتسجيل في المعهد كلِّه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await runConnected(
      context,
      () => AppScope.of(context).catalog.activateCourse(course.uuid),
      success: 'صارت «${course.name}» الدورةَ الجارية.',
    );
  }

  Future<void> _edit(BuildContext context, [CourseView? course]) async {
    final name = TextEditingController(text: course?.name ?? '');
    var startsOn = course?.startsOn ?? DateTime.now();
    var endsOn = course?.endsOn;
    var status = course?.status ?? 'draft';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(course == null ? 'دورة جديدة' : 'تحرير الدورة'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدورة',
                    border: OutlineInputBorder(),
                  ),
                ),
                _DateField(
                  label: 'تبدأ في',
                  value: startsOn,
                  onChanged: (value) =>
                      setDialogState(() => startsOn = value ?? startsOn),
                ),
                _DateField(
                  label: 'تنتهي في (اختياري)',
                  value: endsOn,
                  clearable: true,
                  onChanged: (value) => setDialogState(() => endsOn = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسوّدة')),
                    DropdownMenuItem(value: 'active', child: Text('جارية')),
                    DropdownMenuItem(value: 'finished', child: Text('منتهية')),
                    DropdownMenuItem(value: 'archived', child: Text('مؤرشفة')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) {
      return;
    }

    await runConnected(
      context,
      () => AppScope.of(context).catalog.saveCourse(
            uuid: course?.uuid,
            name: name.text.trim(),
            startsOn: startsOn,
            endsOn: endsOn,
            status: status,
          ),
      success: 'حُفظت الدورة.',
    );
  }
}

// ----------------------------------------------------------------- الدوامات

class _ShiftsTab extends StatelessWidget {
  const _ShiftsTab();

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return _TabBody<ShiftView>(
      stream: deps.catalog.watchShifts(),
      emptyMessage: 'لا دوامات في الدورة الجارية.\n'
          'الدوامُ هو ما يحدّد أيامَ الحلقة وساعتَها، ولا جلسةَ بلا دوام.',
      emptyIcon: Icons.schedule_outlined,
      onCreate: () => _edit(context),
      createLabel: 'دوام جديد',
      itemBuilder: (context, shift) => ListTile(
        title: Text(shift.name),
        subtitle: Text(
          '${shift.timeLabel} · ${shift.weekdaysLabel}'
          ' · ${shift.circlesCount} حلقة',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: () => _edit(context, shift),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [ShiftView? shift]) async {
    final name = TextEditingController(text: shift?.name ?? '');
    var startsAt = shift?.startsAt ?? '08:00';
    var endsAt = shift?.endsAt ?? '10:00';
    final weekdays = {...?shift?.weekdays};

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(shift == null ? 'دوام جديد' : 'تحرير الدوام'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدوام',
                    border: OutlineInputBorder(),
                  ),
                ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'يبدأ',
                        value: startsAt,
                        onChanged: (value) =>
                            setDialogState(() => startsAt = value),
                      ),
                    ),
                    Expanded(
                      child: _TimeField(
                        label: 'ينتهي',
                        value: endsAt,
                        onChanged: (value) =>
                            setDialogState(() => endsAt = value),
                      ),
                    ),
                  ],
                ),
                const Text('أيام الدوام'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var day = 0; day < 7; day++)
                      FilterChip(
                        label: Text(ShiftView.weekdayName(day)),
                        selected: weekdays.contains(day),
                        onSelected: (value) => setDialogState(
                          () => value ? weekdays.add(day) : weekdays.remove(day),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              // يومٌ واحدٌ على الأقل — الخادم يشترطه (`weekdays.min:1`)، وقولُه
              // هنا أرخص من رحلةٍ تعود بـ422.
              onPressed: weekdays.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) {
      return;
    }

    await runConnected(
      context,
      () => AppScope.of(context).catalog.saveShift(
            uuid: shift?.uuid,
            courseUuid: shift?.courseUuid,
            name: name.text.trim(),
            startsAt: startsAt,
            endsAt: endsAt,
            weekdays: weekdays.toList()..sort(),
          ),
      success: 'حُفظ الدوام.',
    );
  }
}

// ------------------------------------------------------------------ الحلقات

class _CirclesTab extends StatelessWidget {
  const _CirclesTab();

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return _TabBody<CircleDefinitionView>(
      stream: deps.catalog.watchCircleDefinitions(),
      emptyMessage: 'لا حلقات مُعرَّفة في هذا المعهد.',
      emptyIcon: Icons.groups_2_outlined,
      onCreate: () => _edit(context),
      createLabel: 'حلقة جديدة',
      itemBuilder: (context, circle) => ListTile(
        title: Text(circle.name),
        subtitle: Text(
          circle.isRunning
              // هويّةُ الحلقة ثابتةٌ عبر الدورات، وتشغيلُها صفٌّ ثانٍ — فالفرقُ
              // بين «مُعرَّفة» و«تعمل» يُقال لا يُترك للحدس.
              ? 'تعمل في: ${circle.runningIn.join(' · ')}'
              : 'مُعرَّفة ولم تُشغَّل في الدورة الجارية',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _run(context, circle),
              child: Text(circle.isRunning ? 'تشغيل في دوام آخر' : 'تشغيل'),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _edit(context, circle),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context, [
    CircleDefinitionView? circle,
  ]) async {
    final name = TextEditingController(text: circle?.name ?? '');
    final level = TextEditingController(text: circle?.level ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(circle == null ? 'حلقة جديدة' : 'تحرير الحلقة'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم الحلقة',
                  border: OutlineInputBorder(),
                ),
              ),
              TextField(
                controller: level,
                decoration: const InputDecoration(
                  labelText: 'المستوى (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) {
      return;
    }

    await runConnected(
      context,
      () => AppScope.of(context).catalog.saveCircle(
            uuid: circle?.uuid,
            name: name.text.trim(),
            level: level.text.trim().isEmpty ? null : level.text.trim(),
          ),
      success: 'حُفظت الحلقة.',
    );
  }

  Future<void> _run(BuildContext context, CircleDefinitionView circle) async {
    final deps = AppScope.of(context);
    final shifts = await deps.catalog.loadShifts();

    if (!context.mounted) {
      return;
    }

    if (shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا دوامَ في الدورة الجارية — أنشئ دواماً أوّلاً.'),
        ),
      );

      return;
    }

    final room = TextEditingController();
    final capacity = TextEditingController();
    String? shiftUuid = shifts.first.uuid;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('تشغيل «${circle.name}»'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: shiftUuid,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الدوام',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final shift in shifts)
                      DropdownMenuItem(
                        value: shift.uuid,
                        child: Text('${shift.name} — ${shift.timeLabel}'),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => shiftUuid = value),
                ),
                TextField(
                  controller: room,
                  decoration: const InputDecoration(
                    labelText: 'القاعة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الطاقة الاستيعابية (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('تشغيل'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) {
      return;
    }

    // وتشغيلُ حلقةٍ مشغَّلةٍ في نفس الدورة يعود **رسالةً مقروءة** لا 500:
    // `RunCircleInCourse` يفحص `unique(course_id, circle_id)` قبل الكتابة.
    await runConnected(
      context,
      () => deps.catalog.runCircle(
        circleUuid: circle.uuid,
        shiftUuid: shiftUuid!,
        room: room.text,
        capacity: int.tryParse(capacity.text),
      ),
      success: 'شُغّلت الحلقةُ في الدوام المختار.',
    );
  }
}

// ------------------------------------------------------------- بناءٌ مشترك

class _TabBody<T> extends StatelessWidget {
  const _TabBody({
    required this.stream,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onCreate,
    required this.createLabel,
    required this.itemBuilder,
  });

  final Stream<List<T>> stream;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback onCreate;
  final String createLabel;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: Text(createLabel),
      ),
      body: StreamBuilder<List<T>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snapshot.data!;

          if (rows.isEmpty) {
            return EmptyState(message: emptyMessage, icon: emptyIcon);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => itemBuilder(context, rows[index]),
          );
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.clearable = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: clearable && value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value == null ? '—' : _date(value!)),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// `HH:MM` أو `HH:MM:SS` — والمعروضُ والمرسَل `HH:MM`.
  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    final time = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);

        if (picked != null) {
          onChanged(
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
          );
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.schedule, size: 18),
        ),
        child: Text(
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}';
