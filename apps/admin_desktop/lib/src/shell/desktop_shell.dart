import 'package:flutter/material.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/institute_menu.dart';
import '../widgets/sync_bar.dart';
import 'destinations.dart';

/// هيكلُ النافذة: قائمةٌ جانبية دائمة على اليمين، والشاشةُ الجارية إلى جانبها،
/// وشريطُ المزامنة أسفلَ الاثنين.
///
/// ### 🔑 قرار م.6.3: بلا `go_router` — وهنا حُسمت المسألة المؤجَّلة من م.5.3
/// ([PLAN.md §7](../../../../../docs/PLAN.md))
///
/// كان السؤال: تنقّلُ الديسكتوب أعقد من ثماني شاشات، أفلا يستحقّ موجّهاً؟
/// والجواب لا، لثلاثة أسباب قِيست على هذا الهيكل بعد بنائه:
///
/// 1. **ما يبيعه الموجّه ليس مطلوباً هنا.** قيمتُه الأولى تحويلُ مسارٍ نصّيّ إلى
///    شجرةِ شاشات: روابطُ عميقة، وشريطُ عنوانٍ في المتصفّح، واستعادةُ حالةٍ من
///    نظام التشغيل. وهذا برنامجُ نافذةٍ واحدة على ويندوز بلا واحدةٍ من الثلاث.
/// 2. **كلُّ بابٍ يحتاج مكدّسَه** — مشرفٌ في منتصف استمارة طالب يفتح كشفَ
///    الحلقات ثم يعود فيجد استمارتَه كما تركها. وهذا ما يعطيه [IndexedStack] فوق
///    `Navigator` لكل باب مجاناً. ونظيرُه في الموجّه `StatefulShellRoute` — أي
///    **نفسُ هذا التركيب** بمفرداتٍ ثانية فوقه.
/// 3. **الأبوابُ تُرشَّح في زمن التشغيل** بـ`user.permissions`، لا جدولَ مساراتٍ
///    ثابتاً يُكتب مرّة. ومع الموجّه كان الحارسُ سيُكتب مرّتين: مرّةً في ترشيح
///    القائمة ومرّةً في `redirect` كي لا يُبلَغ المسارُ من غير القائمة.
///
/// فبقي التطبيقان — الأستاذُ والديسكتوب — على `Navigator` و`InheritedWidget`
/// واحد، ولم تدخل الحزمةُ ولا مفرداتُها.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  /// معرّفُ الباب لا رقمُه: ترشيحُ الأبواب يتغيّر مع اللقطة (تبديلُ معهدٍ يغيّر
  /// صلاحياتِ صاحبه)، ورقمٌ محفوظٌ كان سيشير إلى بابٍ آخر بعد أن تقصر القائمة.
  String? _selectedId;

  final Map<String, GlobalKey<NavigatorState>> _navigators = {};

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final sections = visibleSections(session.snapshot);

    if (sections.isEmpty) {
      return const _NoDoors();
    }

    final selected = sections.any((section) => section.id == _selectedId)
        ? _selectedId!
        : sections.first.id;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  sections: sections,
                  selectedId: selected,
                  onSelect: (id) => setState(() => _selectedId = id),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: sections.indexWhere((s) => s.id == selected),
                    children: [
                      for (final section in sections)
                        _SectionHost(
                          key: ValueKey(section.id),
                          navigatorKey: _navigators.putIfAbsent(
                            section.id,
                            GlobalKey<NavigatorState>.new,
                          ),
                          section: section,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const AppSyncBar(),
        ],
      ),
    );
  }
}

/// مكدّسُ بابٍ واحد — `Navigator` مستقلّ، فما يُفتح داخله لا يغطّي القائمة
/// الجانبية ولا يضيع حين ينتقل المستخدمُ إلى بابٍ آخر ويعود.
class _SectionHost extends StatelessWidget {
  const _SectionHost({
    super.key,
    required this.navigatorKey,
    required this.section,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final DesktopSection section;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: section.builder,
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.sections,
    required this.selectedId,
    required this.onSelect,
  });

  static const double width = 248;

  final List<DesktopSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <SectionGroup, List<DesktopSection>>{};

    for (final section in sections) {
      groups.putIfAbsent(section.group, () => []).add(section);
    }

    return SizedBox(
      width: width,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            const InstituteMenu(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        entry.key.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final section in entry.value)
                      _SidebarTile(
                        section: section,
                        selected: section.id == selectedId,
                        onTap: () => onSelect(section.id),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            const _AccountFooter(),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final DesktopSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        selectedColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(section.icon, size: 20),
        title: Text(section.label, style: theme.textTheme.bodyMedium),
        onTap: onTap,
      ),
    );
  }
}

/// اسمُ صاحب الجهاز وخروجُه — أسفلَ القائمة كما في كل برنامج مكتبي.
class _AccountFooter extends StatelessWidget {
  const _AccountFooter();

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final theme = Theme.of(context);
    final snapshot = session.snapshot;

    return ListTile(
      dense: true,
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(
        snapshot?.userName ?? '',
        style: theme.textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        snapshot?.roles.join(' · ') ?? '',
        style: theme.textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'خروج',
        icon: const Icon(Icons.logout, size: 18),
        onPressed: session.signOut,
      ),
    );
  }
}

/// حسابٌ دخل ولا بابَ له في هذا المعهد.
///
/// لا يقع لدورٍ مسنَد صحيحاً، لكنه يقع لحسابٍ نُزعت أدوارُه وهو داخلٌ — والبديلُ
/// عنه نافذةٌ بيضاء لا يعرف صاحبُها أدخل أم لا.
class _NoDoors extends StatelessWidget {
  const _NoDoors();

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EmptyState(
                icon: Icons.lock_outline,
                message: 'لا تملك صلاحيةً واحدة في هذا المعهد.\n'
                    'راجِع مديرَ المعهد ليُسند إليك دوراً.',
              ),
              const SizedBox(height: 12),
              const InstituteMenu(compact: true),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: session.signOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('خروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
