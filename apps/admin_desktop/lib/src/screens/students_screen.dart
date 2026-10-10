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

  /// ترشيحٌ بالحالة — والافتراضيُّ **الفعّالون وحدهم**: كشفٌ يخلط المتخرّجين
  /// والمنقطعين بالحاضرين يطول بلا فائدةٍ يومية.
  String _status = 'active';

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

          final students = all.where(_matches).toList();

          return Column(
            children: [
              _Filters(
                controller: _search,
                status: _status,
                onQuery: (value) => setState(() => _query = value.trim()),
                onStatus: (value) => setState(() => _status = value),
                total: all.length,
                shown: students.length,
              ),
              const Divider(height: 1),
              Expanded(
                child: students.isEmpty
                    ? const EmptyState(
                        message: 'لا طالب يطابق البحث.',
                        icon: NzIcons.search,
                      )
                    : _StudentTable(
                        resetKey: '$_query|$_status',
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

  bool _matches(StudentListEntry student) {
    if (_status != 'all' && student.status != _status) {
      return false;
    }

    if (_query.isEmpty) {
      return true;
    }

    // البحثُ يشمل رقمَ البطاقة والجوّال: المشرف يمسك بطاقةَ الطالب في يده أكثر
    // مما يتذكّر تهجئةَ اسمه.
    return [
      student.fullName,
      student.registrationNo ?? '',
      student.phone ?? '',
      student.circleName ?? '',
    ].any((field) => field.contains(_query));
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
    required this.status,
    required this.onQuery,
    required this.onStatus,
    required this.total,
    required this.shown,
  });

  final TextEditingController controller;
  final String status;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onStatus;
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
            ? 'الاسم أو البطاقة أو الجوّال أو الحلقة'
            : 'ابحث بالاسم أو رقم البطاقة أو الجوّال أو الحلقة',
        border: const OutlineInputBorder(),
      ),
    );
    final filter = DropdownButtonFormField<String>(
      initialValue: status,
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
      onChanged: (value) => onStatus(value ?? 'active'),
    );
    final count = Text(
      shown == total ? '$total طالباً' : '$shown من $total',
      style: Theme.of(context).textTheme.labelMedium,
    );

    // الهاتف: البحثُ بعرض الشاشة، والحالةُ والعددُ تحته.
    if (context.isCompact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          spacing: 12,
          children: [
            search,
            Row(
              spacing: 12,
              children: [
                Expanded(child: filter),
                count,
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(flex: 3, child: search),
          Expanded(flex: 2, child: filter),
          count,
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
