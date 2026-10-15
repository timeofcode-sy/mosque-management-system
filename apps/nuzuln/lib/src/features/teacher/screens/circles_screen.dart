import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../../../config.dart';
import '../di/app_scope.dart';
import '../widgets/sync_button.dart';
import 'announcements_screen.dart';
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
        leadingWidth: 64,
        leading: const Center(child: BrandMark(size: 40)),
        title: Text(snapshot?.institute.name ?? 'حلقاتي'),
        // المزامنةُ زرٌّ يتبدّل شكلُه بالحال لا شريطٌ يأكل من الشاشة، وما لا يتّسع له شريطُ
        // هاتفٍ بعرض 360 في قائمة «المزيد».
        actions: [
          const AppSyncButton(),
          IconButton(
            tooltip: 'الإعلانات',
            icon: const NzIcon(NzIcons.announcement),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AnnouncementsScreen(),
              ),
            ),
          ),
          AboutMenuButton(
            app: AppConfig.about,
            leading: [
              AboutMenuEntry(
                label: 'سجل الجلسات',
                icon: NzIcons.clock,
                onSelected: teacherUuid == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SessionsLogScreen(),
                        ),
                      ),
              ),
            ],
            trailing: [
              AboutMenuEntry(
                label: 'تسجيل الخروج',
                icon: NzIcons.logout,
                danger: true,
                onSelected: () => _confirmSignOut(context),
              ),
            ],
          ),
        ],
      ),
      body: _body(context, teacherUuid, snapshot?.courseName),
    );
  }

  Widget _body(BuildContext context, String? teacherUuid, String? courseName) {
    final deps = AppScope.of(context);

    if (teacherUuid == null) {
      // حسابٌ ليس حساب أستاذ، أو لقطةٌ من خادمٍ أقدم لا يبعث `teacher_uuid`.
      return const EmptyState(
        message: 'هذا الحساب ليس حساب أستاذ، أو لم تصل بياناتُه بعد.\nجرّب المزامنة ثم أعد الفتح.',
        icon: NzIcons.userMinus,
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
            icon: NzIcons.certificate,
            onRetry: deps.sync.syncNow,
          );
        }

        // الحديثُ الذي سُمّي منه النظامُ في رأس الرئيسيّة، ثم الحلقات.
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: circles.length + 1,
          separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 16 : 8),
          itemBuilder: (context, index) => index == 0
              ? const HomeHadith(padding: EdgeInsets.zero)
              : _CircleCard(circle: circles[index - 1]),
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
        trailing: const NzIcon(NzIcons.chevronLeft),
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
