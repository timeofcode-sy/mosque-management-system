import 'package:flutter/material.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/institute_menu.dart';
import '../widgets/sync_bar.dart';
import 'destinations.dart';
import 'sidebar_prefs.dart';

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

  /// 🔑 م.6.5 — **الأبوابُ تُبنى عند أوّل زيارة لا عند الإقلاع.**
  ///
  /// [IndexedStack] يبني أبناءه كلَّهم ويعرض واحداً؛ وهو ما يعطي «لكلِّ بابٍ
  /// مكدّسُه» مجاناً (§2 البند 2). وكان بلا ثمنٍ ما دامت الأبوابُ placeholder،
  /// فلمّا مُلئت في هذه المرحلة صار الإقلاعُ يشغّل `initState` لخمسةَ عشرَ
  /// باباً — ومنها ثلاثةٌ تقرأ من الشبكة (`/admin/users` · `/admin/roles` ·
  /// `/admin/credentials`)، فيرسل التطبيقُ ثلاثةَ طلباتٍ لم يطلبها أحد ويعرض
  /// أخطاءَها لمن لم يفتح بابَها.
  ///
  /// فيُبنى البابُ عند أوّل اختيارٍ له **ويبقى مبنيّاً بعده** — فالمكدّسُ محفوظ
  /// كما كان، والثمنُ يُدفع لِما يُفتح وحده.
  final Set<String> _visited = {};

  /// طيُّ القائمة بخيار المشرف (يُحفظ). ودون 1024px تُطوى القائمةُ وحدها مهما كان الخيار.
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    SidebarPrefs.loadCollapsed().then((value) {
      if (mounted && value != _collapsed) {
        setState(() => _collapsed = value);
      }
    });
  }

  void _toggleSidebar() {
    setState(() => _collapsed = !_collapsed);
    SidebarPrefs.saveCollapsed(_collapsed);
  }

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

    _visited.add(selected);

    // الهوية: القائمةُ الكاملة (264px) من 1024px فما فوق، ودونها شريطُ التنقّل المطويّ (80px)؛
    // وفوقها يطويها المشرفُ بزرّ الطيّ ويوسّعها متى شاء.
    final narrow = MediaQuery.sizeOf(context).width < NzBreakpoint.expanded;
    final rail = narrow || _collapsed;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  sections: sections,
                  selectedId: selected,
                  rail: rail,
                  onToggle: narrow ? null : _toggleSidebar,
                  onSelect: (id) => setState(() => _selectedId = id),
                ),
                Expanded(
                  child: IndexedStack(
                    index: sections.indexWhere((s) => s.id == selected),
                    children: [
                      for (final section in sections)
                        if (_visited.contains(section.id))
                          _SectionHost(
                            key: ValueKey(section.id),
                            navigatorKey: _navigators.putIfAbsent(
                              section.id,
                              GlobalKey<NavigatorState>.new,
                            ),
                            section: section,
                          )
                        else
                          SizedBox.shrink(key: ValueKey(section.id)),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
      onGenerateRoute: (settings) =>
          MaterialPageRoute<void>(settings: settings, builder: section.builder),
    );
  }
}

/// القائمةُ الجانبية (`SideNav` في الهوية): 264px بعناوين أقسامٍ بحجم 12 وعناصرَ بارتفاع 40، والعنصرُ
/// الحاليّ bronze-soft بخطٍّ أثقل. وتحت 1024px تطوى إلى شريطٍ بعرض 80px أيقوناتُه وحدها (مع تلميح).
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.sections,
    required this.selectedId,
    required this.onSelect,
    required this.rail,
    required this.onToggle,
  });

  final List<DesktopSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool rail;

  /// `null` حين لا يملك المشرفُ الخيار (النافذةُ ضيّقة فالقائمةُ مطويّةٌ قسراً).
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final groups = <SectionGroup, List<DesktopSection>>{};

    for (final section in sections) {
      groups.putIfAbsent(section.group, () => []).add(section);
    }

    // بلا تحريكٍ للعرض عمداً: المحتوى يتبدّل بين القائمة الكاملة والأيقونات، والتحريكُ يُظهر الاثنين
    // في عرضٍ وسيط فيفيض أحدُهما. والتبديلُ الفوريّ أوضحُ وأرخص.
    return Container(
      width: rail ? NzSize.railWidth : NzSize.sidenavWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: BorderDirectional(end: BorderSide(color: c.line)),
      ),
      child: Column(
        children: [
          if (rail)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: NzSpace.s4),
              child: BrandMark(size: 40),
            )
          else
            const InstituteMenu(),
          Expanded(
            // شريطُ تمرير القائمة عند أقصى اليمين (حافّة النافذة) لا بينها وبين المحتوى.
            child: Scrollbar(
              scrollbarOrientation: ScrollbarOrientation.right,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: NzSpace.s3,
                  vertical: NzSpace.s2,
                ),
                children: [
                  for (final entry in groups.entries) ...[
                    if (!rail)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          NzSpace.s3,
                          NzSpace.s4,
                          NzSpace.s3,
                          NzSpace.s1,
                        ),
                        child: Text(
                          entry.key.label,
                          style: NzType.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: NzSpace.s3),
                    for (final section in entry.value)
                      _SidebarTile(
                        section: section,
                        selected: section.id == selectedId,
                        rail: rail,
                        onTap: () => onSelect(section.id),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (onToggle != null) _CollapseTile(rail: rail, onTap: onToggle!),
          Divider(height: 1, color: c.line),
          _AccountFooter(rail: rail),
        ],
      ),
    );
  }
}

/// زرُّ طيّ القائمة وتوسيعها: عنصرٌ في أسفل القائمة بالارتفاع نفسه (40px) وتلميحٍ في الحالتين.
class _CollapseTile extends StatelessWidget {
  const _CollapseTile({required this.rail, required this.onTap});

  final bool rail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final label = rail ? 'توسيع القائمة' : 'طيّ القائمة';
    final radius = BorderRadius.circular(NzRadius.sm);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NzSpace.s3,
        vertical: NzSpace.s1,
      ),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              hoverColor: c.surfaceSunken,
              onTap: onTap,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: rail ? 0 : NzSpace.s3,
                  ),
                  child: Row(
                    mainAxisAlignment: rail
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      NzIcon(NzIcons.menu, size: 22, color: c.inkMuted),
                      if (!rail) ...[
                        const SizedBox(width: NzSpace.s3),
                        Text(
                          label,
                          style: NzType.label.copyWith(
                            fontSize: 14,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.section,
    required this.selected,
    required this.rail,
    required this.onTap,
  });

  final DesktopSection section;
  final bool selected;
  final bool rail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final fg = selected ? c.bronzeInk : c.ink;
    final radius = BorderRadius.circular(NzRadius.sm);

    final tile = Semantics(
      selected: selected,
      button: true,
      label: section.label,
      child: Material(
        color: selected ? c.bronzeSoft : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          hoverColor: c.surfaceSunken,
          onTap: onTap,
          child: SizedBox(
            height: rail ? 48 : 40,
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: rail ? 0 : NzSpace.s3,
              ),
              child: Row(
                mainAxisAlignment: rail
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  NzIcon(section.icon, size: 22, color: fg),
                  if (!rail) ...[
                    const SizedBox(width: NzSpace.s3),
                    Expanded(
                      child: Text(
                        section.label,
                        overflow: TextOverflow.ellipsis,
                        style: NzType.label.copyWith(
                          fontSize: 14,
                          color: fg,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: rail ? Tooltip(message: section.label, child: tile) : tile,
    );
  }
}

/// اسمُ صاحب الجهاز وخروجُه — أسفلَ القائمة كما في كل برنامج مكتبي.
class _AccountFooter extends StatelessWidget {
  const _AccountFooter({this.rail = false});

  final bool rail;

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final theme = Theme.of(context);
    final snapshot = session.snapshot;

    if (rail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: NzSpace.s2),
        child: IconButton(
          tooltip: 'خروج — ${snapshot?.userName ?? ''}',
          icon: const NzIcon(NzIcons.logout, size: 22),
          onPressed: session.signOut,
        ),
      );
    }

    return ListTile(
      dense: true,
      leading: const NzIcon(NzIcons.user),
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
        icon: const NzIcon(NzIcons.logout, size: 18),
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
                icon: NzIcons.lockClosed,
                message:
                    'لا تملك صلاحيةً واحدة في هذا المعهد.\n'
                    'راجِع مديرَ المعهد ليُسند إليك دوراً.',
              ),
              const SizedBox(height: 12),
              const InstituteMenu(compact: true),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: session.signOut,
                icon: const NzIcon(NzIcons.logout, size: 18),
                label: const Text('خروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
