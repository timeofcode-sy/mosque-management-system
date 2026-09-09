import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلاب المعهد'),
        actions: [
          // ما لا يملكه المستخدم لا يظهر أصلاً — لا زرَّ معطَّلاً ولا رسالةَ رفض
          // عند الضغط (نفسُ قاعدة القائمة الجانبية في م.6.3).
          if (canManage)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: FilledButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
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
              message: 'لا طلاب في هذا المعهد بعد.\n'
                  'سجّل أوّلَ طالب، أو زامِن الجهازَ إن كان المعهد قائماً.',
              icon: Icons.school_outlined,
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
                        icon: Icons.search_off_outlined,
                      )
                    : _StudentTable(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              onChanged: onQuery,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'ابحث بالاسم أو رقم البطاقة أو الجوّال أو الحلقة',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
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
            ),
          ),
          Text(
            shown == total ? '$total طالباً' : '$shown من $total',
            style: Theme.of(context).textTheme.labelMedium,
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
  });

  final List<StudentListEntry> students;
  final bool canManage;
  final bool canTransfer;
  final ValueChanged<StudentListEntry> onOpen;
  final ValueChanged<StudentListEntry> onEdit;
  final ValueChanged<StudentListEntry> onTransfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: students.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DefaultTextStyle(
              style: theme.textTheme.labelMedium ?? const TextStyle(),
              child: const _Row(
                registration: Text('رقم البطاقة'),
                name: Text('الاسم'),
                circle: Text('الحلقة'),
                phone: Text('الجوّال'),
                actions: SizedBox.shrink(),
              ),
            ),
          );
        }

        final student = students[index - 1];

        return InkWell(
          onTap: () => onOpen(student),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _Row(
              registration: Text(student.registrationNo ?? '—'),
              name: Row(
                spacing: 8,
                children: [
                  Flexible(child: Text(student.fullName)),
                  // وسمُ «لم تصل بعد» — وإلا ظنّ المشرف أن حفظَه ضاع فأعاده.
                  if (student.pending)
                    Tooltip(
                      message: 'كتابةٌ لم تصل الخادمَ بعد',
                      child: Icon(
                        Icons.cloud_upload_outlined,
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
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEdit(student),
                    ),
                  if (canTransfer)
                    IconButton(
                      tooltip: 'نقل إلى حلقة أخرى',
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      onPressed: () => onTransfer(student),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
