import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'transfer_dialog.dart';

/// التسجيلُ والنقل — ✅ م.6.5.
///
/// **وهي شاشةٌ مقلوبةُ الترتيب عن «الطلاب»**: تلك تبدأ من الطالب وتسأل «أين
/// حلقته؟»، وهذه تبدأ من الحلقة وتسأل «من فيها ومن ينقصها». والمشرفُ يفتح هذه
/// أوّلَ الدورة حين يوزّع مئةَ طالبٍ على عشر حلقات، وتلك حين يسأل عن طالبٍ بعينه.
class EnrollmentsScreen extends StatefulWidget {
  const EnrollmentsScreen({super.key});

  @override
  State<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends State<EnrollmentsScreen> {
  String? _circle;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final canEnroll = deps.session.can('enrollments.manage');
    final canTransfer = deps.session.can('transfers.manage');

    return Scaffold(
      appBar: const _EnrollmentsBar(),
      body: FutureBuilder<List<CircleView>>(
        future: deps.circles.loadCircles(),
        builder: (context, circleSnapshot) {
          if (!circleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final circles = circleSnapshot.data!;

          if (circles.isEmpty) {
            return EmptyState(
              message: 'لا حلقات في الدورة الجارية.\n'
                  'هيّئ الدورةَ ودواماتِها وحلقاتِها أوّلاً من باب «الدورات والدوامات».',
              icon: Icons.groups_2_outlined,
              onRetry: deps.sync.syncNow,
            );
          }

          return StreamBuilder<List<StudentListEntry>>(
            stream: deps.students.watchStudents(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final students = snapshot.data!
                  .where((student) => student.status == 'active')
                  .toList();

              final unassigned =
                  students.where((s) => s.circleName == null).toList();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    child: _CircleList(
                      circles: circles,
                      selected: _circle,
                      onSelect: (uuid) => setState(() => _circle = uuid),
                      unassignedCount: unassigned.length,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _circle == null
                        ? _Unassigned(
                            students: unassigned,
                            circles: circles,
                            canEnroll: canEnroll,
                          )
                        : _Roster(
                            circle: circles
                                .firstWhere((c) => c.uuid == _circle),
                            students: students,
                            canTransfer: canTransfer,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EnrollmentsBar extends StatelessWidget implements PreferredSizeWidget {
  const _EnrollmentsBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('التسجيل والنقل'));
}

class _CircleList extends StatelessWidget {
  const _CircleList({
    required this.circles,
    required this.selected,
    required this.onSelect,
    required this.unassignedCount,
  });

  final List<CircleView> circles;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final int unassignedCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          selected: selected == null,
          leading: const Icon(Icons.person_search_outlined),
          title: const Text('بلا حلقة'),
          trailing: Text('$unassignedCount'),
          onTap: () => onSelect(null),
        ),
        const Divider(),
        for (final circle in circles)
          ListTile(
            selected: selected == circle.uuid,
            title: Text(circle.circleName),
            subtitle: Text(
              '${circle.shiftName} — ${circle.studentsCount} طالباً'
              '${circle.capacity == null ? '' : ' من ${circle.capacity}'}',
            ),
            // الحلقةُ الممتلئة تُقال قبل الضغط لا بعده: الطاقةُ الاستيعابية
            // يحرسها `EnrollStudent` على الخادم، وردُّه يصل بعد دورة مزامنة.
            trailing: circle.capacity != null &&
                    circle.studentsCount >= circle.capacity!
                ? Tooltip(
                    message: 'بلغت طاقتها الاستيعابية',
                    child: Icon(
                      Icons.block,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : null,
            onTap: () => onSelect(circle.uuid),
          ),
      ],
    );
  }
}

class _Unassigned extends StatelessWidget {
  const _Unassigned({
    required this.students,
    required this.circles,
    required this.canEnroll,
  });

  final List<StudentListEntry> students;
  final List<CircleView> circles;
  final bool canEnroll;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const EmptyState(
        message: 'كلُّ طالبٍ فعّال مسجَّلٌ في حلقة.',
        icon: Icons.done_all,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final student = students[index];

        return ListTile(
          title: Text(student.fullName),
          subtitle: Text(student.registrationNo ?? 'بلا رقم بطاقة'),
          trailing: canEnroll
              ? FilledButton.tonal(
                  onPressed: () => _enroll(context, student),
                  child: const Text('تسجيل في حلقة'),
                )
              : null,
        );
      },
    );
  }

  Future<void> _enroll(BuildContext context, StudentListEntry student) async {
    final target = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('تسجيل ${student.fullName}'),
        children: [
          for (final circle in circles)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(circle.uuid),
              child: Text('${circle.circleName} — ${circle.shiftName}'),
            ),
        ],
      ),
    );

    if (target == null || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    await AppScope.of(context).students.enrollStudent(
          studentUuid: student.uuid,
          courseCircleUuid: target,
        );

    messenger.showSnackBar(
      const SnackBar(content: Text('صُفَّ التسجيلُ للمزامنة.')),
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({
    required this.circle,
    required this.students,
    required this.canTransfer,
  });

  final CircleView circle;
  final List<StudentListEntry> students;
  final bool canTransfer;

  @override
  Widget build(BuildContext context) {
    final roster = students
        .where((student) => student.circleName == circle.circleName)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${circle.circleName} — ${roster.length} طالباً',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: roster.isEmpty
              ? const EmptyState(
                  message: 'لا طلاب في هذه الحلقة بعد.',
                  icon: Icons.person_off_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: roster.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    title: Text(roster[index].fullName),
                    subtitle: Text(roster[index].registrationNo ?? '—'),
                    trailing: canTransfer
                        ? IconButton(
                            tooltip: 'نقل إلى حلقة أخرى',
                            icon: const Icon(Icons.swap_horiz),
                            onPressed: () => showTransferDialog(
                              context,
                              student: roster[index],
                            ),
                          )
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}
