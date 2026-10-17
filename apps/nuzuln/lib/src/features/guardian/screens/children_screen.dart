import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'announcements_screen.dart';
import 'excuses_screen.dart';
import 'submit_excuse_screen.dart';

/// يفتح لسانَ ابنٍ بعينه في الشريط السفلي: 1 الحضور · 2 الحفظ · 3 السلوك.
typedef OpenChild = void Function(GuardianChild child, int tab);

/// الرئيسية: تحيّةٌ وأبناءُ صاحب الحساب في هذا المعهد، ولكلّ ابنٍ أبوابُه.
///
/// وهي سببُ **عدم توسيع `/bootstrap`** في م.7.1: اللقطةُ تعطي كلَّ الأدوار
/// الهويّةَ والمعهدَ وثيمَه، وحلقاتُها لا تعني وليَّ الأمر شيئاً — شاشتُه الأولى
/// أبناؤه، ولهم نقطتُهم.
class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key, this.onOpenChild, this.onChildren});

  final OpenChild? onOpenChild;

  /// قائمةُ الأبناء كلّما قُرئت — يبني منها الشريطُ مبدّلَ الابن في ألسنته.
  final ValueChanged<List<GuardianChild>>? onChildren;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final snapshot = scope.session.snapshot;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: const Center(child: BrandMark(size: 40)),
        title: const Text('الرئيسية'),
        actions: const [AnnouncementsAction()],
      ),
      body: SnapshotView<List<GuardianChild>>(
        load: () async {
          final loaded = (await scope.repository.children()).ui;
          onChildren?.call(loaded.value);

          return loaded;
        },
        emptyMessage:
            'لا أبناءَ مسجَّلون على هذا الحساب.\n'
            'راجع إدارة المعهد إن كان هذا غيرَ متوقَّع.',
        errorMessageBuilder: messageFor,
        isEmpty: (children) => children.isEmpty,
        builder: (context, children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Greeting(
              name: snapshot?.userName ?? 'حسابي',
              institute: snapshot?.institute.name,
              count: children.length,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text('أبنائي', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final child in children) _ChildCard(child: child, onOpen: onOpenChild),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ListTile(
                leading: NzIcon(NzIcons.envelopeOpen, color: context.nz.bronzeInk),
                title: const Text('أعذار الغياب'),
                subtitle: const Text('ما قدّمتَه من أعذار، وجوابُ الإدارة عليها'),
                trailing: const NzIcon(NzIcons.chevronLeft),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ExcusesScreen()),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: HomeHadith(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.count, this.institute});

  final String name;
  final String? institute;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final scheme = Theme.of(context).colorScheme;
    final children = switch (count) {
      1 => 'ابنٌ واحد',
      2 => 'ابنان',
      _ => '$count أبناء',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NzRadius.md),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [scheme.primary, Color.lerp(scheme.primary, Colors.black, 0.35)!],
        ),
      ),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  'السلام عليكم',
                  style: NzType.caption.copyWith(color: scheme.onPrimary.withValues(alpha: 0.8)),
                ),
                Text(
                  name,
                  style: NzType.title.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                ),
                Text(
                  [?institute, children].join(' · '),
                  style: NzType.caption.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          NzIcon(NzIcons.students, size: 40, color: c.bronzeSoft),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, this.onOpen});

  final GuardianChild child;
  final OpenChild? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final theme = Theme.of(context);

    Widget door(String icon, String label, int tab) => Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            ),
            onPressed: onOpen == null ? null : () => onOpen!(child, tab),
            icon: NzIcon(icon, size: 16),
            label: Text(label, overflow: TextOverflow.ellipsis),
          ),
        );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: c.bronzeSoft,
                  child: Text(
                    child.fullName.characters.first,
                    style: NzType.title.copyWith(color: c.bronzeInk),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.fullName, style: theme.textTheme.titleMedium),
                      if (child.registrationNo != null)
                        Text(
                          'رقم المعرف ${child.registrationNo}',
                          style: NzType.caption.copyWith(color: c.inkMuted),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تقديم عذر',
                  icon: const NzIcon(NzIcons.envelope),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SubmitExcuseScreen(child: child)),
                  ),
                ),
              ],
            ),
            Row(
              spacing: 8,
              children: [
                door(NzIcons.attendance, 'الحضور', 1),
                door(NzIcons.mushaf, 'الحفظ', 2),
                door(NzIcons.star, 'السلوك', 3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
