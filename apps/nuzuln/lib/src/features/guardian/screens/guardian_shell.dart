import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../../../config.dart';
import '../di/app_scope.dart';
import 'announcements_screen.dart';
import 'child_views.dart';
import 'children_screen.dart';
import 'excuses_screen.dart';
import 'submit_excuse_screen.dart';

/// سطحُ وليّ الأمر على نمط سطح الطالب: الرئيسية · الحضور · الحفظ · السلوك · المزيد.
///
/// ألسنةُ الحضور والحفظ والسلوك **لابنٍ واحدٍ في كل مرّة**: يُختار من بطاقته في الرئيسية أو
/// من رأس اللسان حين يكون للحساب أكثرُ من ابن. وكلُّ لسانٍ يُبنى عند أوّل زيارة، كما في الطالب.
class GuardianShell extends StatefulWidget {
  const GuardianShell({super.key});

  @override
  State<GuardianShell> createState() => _GuardianShellState();
}

class _GuardianShellState extends State<GuardianShell> {
  int _index = 0;
  final Set<int> _visited = {0};
  List<GuardianChild> _children = const [];
  String? _selected;

  static const _destinations = [
    (icon: NzIcons.home, label: 'الرئيسية'),
    (icon: NzIcons.attendance, label: 'الحضور'),
    (icon: NzIcons.mushaf, label: 'الحفظ'),
    (icon: NzIcons.star, label: 'السلوك'),
    (icon: NzIcons.more, label: 'المزيد'),
  ];

  GuardianChild? get _child =>
      _children.where((child) => child.uuid == _selected).firstOrNull ?? _children.firstOrNull;

  void _open(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  void _openChild(GuardianChild child, int tab) {
    _selected = child.uuid;
    _open(tab);
  }

  /// تصل من قراءة الرئيسية — وقد تصل أثناء البناء، فتُؤجَّل إلى ما بعده.
  void _onChildren(List<GuardianChild> children) {
    if (listEquals(children, _children)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _children = children);
      }
    });
  }

  Widget _tab(int index) => switch (index) {
        0 => ChildrenScreen(onOpenChild: _openChild, onChildren: _onChildren),
        1 || 2 || 3 => _ChildTab(
            tab: index,
            children: _children,
            child: _child,
            onSelect: (child) => setState(() => _selected = child.uuid),
          ),
        _ => const _More(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _destinations.length; i++)
            _visited.contains(i) ? _tab(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _open,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: NzIcon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _ChildTab extends StatelessWidget {
  const _ChildTab({
    required this.tab,
    required this.children,
    required this.child,
    required this.onSelect,
  });

  final int tab;
  final List<GuardianChild> children;
  final GuardianChild? child;
  final ValueChanged<GuardianChild> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = child;
    final title = switch (tab) {
      1 => 'الحضور',
      2 => 'الحفظ',
      _ => 'السلوك',
    };

    return Scaffold(
      appBar: AppBar(
        title: selected == null
            ? Text(title)
            : _ChildSwitcher(
                title: title,
                children: children,
                selected: selected,
                onSelect: onSelect,
              ),
        actions: const [AnnouncementsAction()],
      ),
      floatingActionButton: tab == 1 && selected != null
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => SubmitExcuseScreen(child: selected)),
              ),
              icon: const NzIcon(NzIcons.envelope),
              label: const Text('تقديم عذر'),
            )
          : null,
      body: selected == null
          ? const EmptyState(
              message: 'لا أبناءَ لعرضهم بعد.\nاسحب الرئيسية إلى الأسفل لتحديثها.',
              icon: NzIcons.students,
            )
          // مفتاحٌ بالابن: تبديلُه يعيد القراءة لا يُبقي أرقامَ أخيه.
          : KeyedSubtree(
              key: ValueKey('${selected.uuid}-$tab'),
              child: switch (tab) {
                1 => ChildAttendanceView(childUuid: selected.uuid),
                2 => ChildProgressView(childUuid: selected.uuid),
                _ => ChildBehaviorView(childUuid: selected.uuid),
              },
            ),
    );
  }
}

/// رأسُ اللسان: اسمُ اللسان واسمُ الابن — وبسهمٍ يبدّله حين يكون للحساب أكثرُ من ابن.
class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({
    required this.title,
    required this.children,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<GuardianChild> children;
  final GuardianChild selected;
  final ValueChanged<GuardianChild> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          selected.fullName,
          style: NzType.caption.copyWith(color: c.inkMuted),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (children.length < 2) {
      return label;
    }

    return PopupMenuButton<GuardianChild>(
      tooltip: 'اختيار الابن',
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final child in children)
          CheckedPopupMenuItem(
            value: child,
            checked: child.uuid == selected.uuid,
            child: Text(child.fullName),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Flexible(child: label),
          const NzIcon(NzIcons.chevronDown, size: 18),
        ],
      ),
    );
  }
}

class _More extends StatelessWidget {
  const _More();

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final snapshot = session.snapshot;

    return MorePage(
      app: AppConfig.about,
      userName: snapshot?.userName ?? 'حسابي',
      subtitle: [?snapshot?.institute.name, 'وليّ أمر'].join(' · '),
      entries: [
        MoreEntry(
          icon: NzIcons.envelopeOpen,
          label: 'أعذار الغياب',
          subtitle: 'ما قدّمتَه من أعذار، وجوابُ الإدارة عليها',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ExcusesScreen()),
          ),
        ),
        MoreEntry(
          icon: NzIcons.announcement,
          label: 'الإعلانات',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AnnouncementsScreen()),
          ),
        ),
      ],
      onSignOut: session.signOut,
    );
  }
}
