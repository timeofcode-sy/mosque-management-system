import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/adaptive.dart';
import '../widgets/connected_action.dart';
import '../widgets/credentials_dialog.dart';
import '../widgets/sync_bar.dart';

/// الأساتذة — كانوا في لوحة الويب وحدها، خلف `teachers.manage`.
///
/// القراءةُ من drift والكتابةُ REST كـ«الدورات وأوقات الدوام». والاستمارةُ هنا
/// للأعمدة التي تصل الجهاز (الاسمُ والهاتفُ والحالة)؛ وما سواها من سجلّ الأستاذ
/// يبقى كما حُرِّر في اللوحة، فالخادمُ يحدّث الحقولَ المرسَلة وحدها.
class TeachersScreen extends StatelessWidget {
  const TeachersScreen({super.key});

  static const statuses = {
    'active': 'على رأس العمل',
    'suspended': 'موقوف',
    'left': 'منتهي الخدمة',
  };

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأساتذة'),
        actions: const [PhoneSyncAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const NzIcon(NzIcons.userPlus),
        label: const Text('أستاذ جديد'),
      ),
      body: StreamBuilder<List<TeacherEntry>>(
        stream: deps.content.watchTeachers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final teachers = snapshot.data!;

          if (teachers.isEmpty) {
            return const EmptyState(
              message: 'لا أساتذة في هذا المعهد بعد.',
              icon: NzIcons.user,
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(context.gutter(), 16, context.gutter(), 96),
            itemCount: teachers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _row(context, teachers[index]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, TeacherEntry teacher) {
    final actions = [
      RowAction(
        icon: NzIcons.key,
        label: 'إنشاء حساب دخول',
        onPressed: () => _account(context, teacher),
      ),
      RowAction(
        icon: NzIcons.edit,
        label: 'تحرير',
        onPressed: () => _edit(context, teacher),
      ),
      RowAction(
        icon: NzIcons.trash,
        label: 'حذف',
        destructive: true,
        onPressed: () => _delete(context, teacher),
      ),
    ];

    return ListTile(
      leading: CircleAvatar(
        child: Text(teacher.displayName.isEmpty ? '؟' : teacher.displayName.characters.first),
      ),
      title: Text(teacher.displayName),
      subtitle: Text(
        [
          statuses[teacher.status] ?? teacher.status,
          if (teacher.phone != null && teacher.phone!.isNotEmpty) teacher.phone!,
        ].join(' · '),
      ),
      trailing: context.isCompact
          ? RowActionsMenu(actions: actions)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in actions)
                  IconButton(
                    tooltip: action.label,
                    onPressed: action.onPressed,
                    icon: NzIcon(
                      action.icon,
                      size: 18,
                      color: action.destructive ? context.nz.danger : null,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, [TeacherEntry? teacher]) async {
    final name = TextEditingController(text: teacher?.displayName ?? '');
    final phone = TextEditingController(text: teacher?.phone ?? '');
    var status = teacher?.status ?? 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(teacher == null ? 'أستاذ جديد' : 'تحرير الأستاذ'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'الهاتف',
                    border: OutlineInputBorder(),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in statuses.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (value) => setDialogState(() => status = value ?? status),
                ),
                if (teacher == null)
                  Text(
                    'يُنشأ حسابُ دخوله مع السجلّ، وبقيةُ بياناته تُحرَّر من لوحة الويب.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
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

    final deps = AppScope.of(context);

    await runConnected(
      context,
      () => deps.content.saveTeacher(
        uuid: teacher?.uuid,
        displayName: name.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        status: status,
      ),
      success: teacher == null ? 'أُضيف الأستاذ.' : 'حُفظ الأستاذ.',
    );
  }

  Future<void> _account(BuildContext context, TeacherEntry teacher) async {
    final deps = AppScope.of(context);
    IssuedCredentials? issued;

    final ok = await runConnected(
      context,
      () async {
        issued = await deps.content.generateTeacherAccount(teacher.uuid);
      },
      success: 'أُنشئ حسابُ ${teacher.displayName}.',
    );

    if (ok && issued != null && context.mounted) {
      await showCredentialsDialog(context, issued!);
    }
  }

  Future<void> _delete(BuildContext context, TeacherEntry teacher) async {
    final confirmed = await confirmAction(
      context,
      title: 'حذف الأستاذ',
      message: 'سيُحذف «${teacher.displayName}» من قائمة الأساتذة.\n'
          'وتبقى جلساتُه وتفقّداتُه السابقة في السجلّ.',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final deps = AppScope.of(context);

    await runConnected(
      context,
      () => deps.content.deleteTeacher(teacher.uuid),
      success: 'حُذف الأستاذ.',
    );
  }
}
