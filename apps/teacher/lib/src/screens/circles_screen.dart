import 'package:flutter/material.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../data/views.dart';
import '../di/app_scope.dart';
import '../widgets/sync_bar.dart';
import 'attendance_screen.dart';
import 'sessions_log_screen.dart';

/// «حلقاتي» — الشاشة الأولى بعد الدخول.
///
/// تُقرأ من drift لا من `/teacher/circles`: اللقطة الأولى تصل في `/bootstrap`،
/// وما بعدها يصل في `sync/pull`، فالشاشة تعمل بلا شبكة من أول إقلاعٍ ثانٍ.
class CirclesScreen extends StatelessWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final session = deps.session;
    final snapshot = session.snapshot;
    final teacherUuid = session.teacherUuid;

    return Scaffold(
      appBar: AppBar(
        title: Text(snapshot?.institute.name ?? 'حلقاتي'),
        actions: [
          IconButton(
            tooltip: 'سجل الجلسات',
            icon: const Icon(Icons.history),
            onPressed: teacherUuid == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SessionsLogScreen(),
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: Column(
        children: [
          const SyncBar(),
          const Divider(height: 1),
          Expanded(child: _body(context, teacherUuid, snapshot?.courseName)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, String? teacherUuid, String? courseName) {
    final deps = AppScope.of(context);

    if (teacherUuid == null) {
      // حسابٌ ليس حساب أستاذ، أو لقطةٌ من خادمٍ أقدم لا يبعث `teacher_uuid`.
      return const EmptyState(
        message: 'هذا الحساب ليس حساب أستاذ، أو لم تصل بياناتُه بعد.\nجرّب المزامنة ثم أعد الفتح.',
        icon: Icons.person_off_outlined,
      );
    }

    return StreamBuilder<List<CircleView>>(
      stream: deps.repository.watchCircles(teacherUuid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final circles = snapshot.data!;

        if (circles.isEmpty) {
          // حالةٌ مفهومة لا شاشةٌ فارغة: لا دورة جارية أصلاً، أو لم تُسنَد حلقة بعد.
          return EmptyState(
            message: courseName == null
                ? 'لا دورة جارية في المعهد الآن.\nستظهر حلقاتك فور أن تبدأ الدورة.'
                : 'لم تُسنَد إليك حلقةٌ في «$courseName» بعد.',
            icon: Icons.school_outlined,
            onRetry: deps.sync.syncNow,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: circles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _CircleCard(circle: circles[index]),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final deps = AppScope.of(context);
    final pending = await deps.syncEngine.watchPendingCount().first;

    if (!context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        // الخروج يمسح المخزن المحلي، فالمعلَّق يضيع — تحذيرٌ صريح لا سؤالٌ عام.
        content: Text(
          pending == 0
              ? 'سيُمسح المخزن المحلي على هذا الجهاز.'
              : 'ما زالت $pending عملية بانتظار المزامنة وستضيع بالخروج.\n'
                    'زامِن أولاً إن كنت متّصلاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await deps.session.signOut();
    }
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.circle});

  final CircleView circle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(circle.circleName, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              '${circle.shiftName} · ${circle.shiftStartsAtLabel}',
              if (circle.room != null) _room(circle.room!),
              '${circle.studentsCount} طالباً',
            ].join(' — '),
          ),
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AttendanceScreen(circle: circle, date: DateTime.now()),
          ),
        ),
      ),
    );
  }
}

/// «قاعة 2» لا «قاعة القاعة 2».
///
/// الحقلُ نصٌّ حرٌّ يكتبه المعهد من اللوحة، فبعضُهم يكتب الرقم («2») وبعضُهم يكتب
/// الاسم كاملاً («القاعة 1»). فتُضاف الكلمةُ لمن لم يكتبها ولا تُكرَّر على من كتبها —
/// والفحصُ بالاحتواء لا بالبداية لأن التعريف يسبقها.
String _room(String room) => room.contains('قاعة') ? room : 'قاعة $room';
