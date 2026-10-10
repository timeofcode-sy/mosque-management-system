import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../di/app_scope.dart';
import 'destinations.dart';

/// أبوابُ الشريط السفلي على الهاتف — **أربعةٌ وبابُ «المزيد»**.
///
/// الشريطُ لا يسع خمسةَ عشرَ باباً، ولا يصحّ أن يقصّها أوّلُ القائمة أعمى: فهنا
/// ترتيبٌ بما يفتحه المشرفُ من هاتفه في المسجد — يومُ المعهد، ثم التفقّد، ثم
/// الطلاب، ثم الحلقات. وما لا يملكه صاحبُ الحساب يسقط فيتقدّم ما بعده، فلكلّ دورٍ
/// أبوابُه الأربعة الأقرب. والبقيّةُ في «المزيد» بعناوين القائمة الجانبية نفسها.
const List<String> phonePriority = [
  'dashboard',
  'attendance',
  'students',
  'circles',
  'excuses',
  'enrollments',
  'reports',
];

/// معرّفُ لسان «المزيد» — لا يطابق باباً في الكتالوج.
const String moreTabId = '__more';

/// الأبوابُ الأربعة الأولى للشريط، والباقي لـ«المزيد» بترتيب القائمة الجانبية.
({List<DesktopSection> primary, List<DesktopSection> secondary}) splitPhoneTabs(
  List<DesktopSection> sections,
) {
  final byId = {for (final section in sections) section.id: section};
  final primary = [for (final id in phonePriority) ?byId[id]];

  // دورٌ لا يملك من أبواب الأولوية أربعةً يُكمَل من أوّل الكتالوج.
  for (final section in sections) {
    if (primary.length >= 4) {
      break;
    }

    if (!primary.contains(section)) {
      primary.add(section);
    }
  }

  final shown = primary.take(4).toList();

  return (
    primary: shown,
    secondary: [
      for (final section in sections)
        if (!shown.contains(section)) section,
    ],
  );
}

/// تسميةُ الباب في الشريط: كلمةٌ أو كلمتان تسعهما خانةٌ بعرض خُمس الشاشة.
String phoneLabelOf(DesktopSection section) => switch (section.id) {
  'dashboard' => 'الرئيسية',
  'reports' => 'التقارير',
  'enrollments' => 'التسجيل',
  'excuses' => 'الأعذار',
  'catalog' => 'الدورات',
  'users' => 'المستخدمون',
  'credentials' => 'الدخول',
  'settings' => 'المعهد',
  _ => section.label,
};

/// اسمُ الدور بالعربية كما في `PanelRole::label` على الخادم — واللقطةُ تحمل
/// المفتاحَ وحده. ودورٌ لا يعرفه هذا الإصدار يُعرض بمفتاحه.
String roleLabelOf(String role) => switch (role) {
  'developer' => 'مبرمج',
  'super_admin' => 'المشرف الأعلى',
  'admin' => 'مدير معهد',
  'supervisor' => 'مشرف',
  'teacher' => 'أستاذ',
  'guardian' => 'ولي أمر',
  'student' => 'طالب',
  _ => role,
};

/// عنصرٌ في الشريط السفلي.
class PhoneNavItem {
  const PhoneNavItem({
    required this.id,
    required this.icon,
    required this.label,
    this.badge = 0,
  });

  final String id;
  final String icon;
  final String label;

  /// عددٌ ينتظر صاحبَ الحساب (أعذارٌ لم يُبتّ فيها) — صفرٌ لا يُرسم.
  final int badge;
}

/// الشريطُ السفلي بهوية نزلاً: سطحٌ مرفوع بحدٍّ علويّ، والبابُ الجاري بأرضيةٍ
/// نحاسية هادئة خلف أيقونته وشريطٍ نحاسيّ مائلٍ فوقها — الميلُ 35° نفسُه الذي
/// تُرسم به أشرطةُ الشعار. زوايا 3px لا كبسولات، وتسمياتٌ ظاهرةٌ دائماً بحجم 12.
class PhoneNavBar extends StatelessWidget {
  const PhoneNavBar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<PhoneNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;

  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Material(
      color: c.surfaceRaised,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: _NavButton(
                      item: item,
                      selected: item.id == selectedId,
                      onTap: () => onSelect(item.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PhoneNavItem item;
  final bool selected;
  final VoidCallback onTap;

  static const _motion = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final fg = selected ? c.bronzeInk : c.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.badge > 0
          ? '${item.label}، ${item.badge} بانتظارك'
          : item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        splashColor: c.bronzeSoft,
        highlightColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // الشريطُ النحاسيّ المائل فوق الباب الجاري.
            AnimatedContainer(
              duration: _motion,
              curve: Curves.easeOutCubic,
              width: selected ? 28 : 0,
              height: 4,
              child: CustomPaint(painter: _RibbonPainter(c.bronzeInk)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: _motion,
                        curve: Curves.easeOutCubic,
                        width: selected ? 60 : 40,
                        height: 32,
                        decoration: BoxDecoration(
                          color: selected ? c.bronzeSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(NzRadius.sm),
                        ),
                        alignment: Alignment.center,
                        child: NzIcon(item.icon, size: 22, color: fg),
                      ),
                      if (item.badge > 0)
                        PositionedDirectional(
                          top: -4,
                          end: -2,
                          child: _Badge(count: item.badge),
                        ),
                    ],
                  ),
                  const SizedBox(height: NzSpace.s1),
                  AnimatedDefaultTextStyle(
                    duration: _motion,
                    style: NzType.caption.copyWith(
                      color: fg,
                      height: 1.25,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// متوازي أضلاعٍ بميل الهوية (`nzSlope`) — طرفا الشريط مقصوصان لا مدوَّران.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 8) {
      return;
    }

    final run = size.height / nzSlope;
    final path = Path()
      ..moveTo(run, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - run, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.color != color;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.danger,
        borderRadius: BorderRadius.circular(NzRadius.sm),
        border: Border.all(color: c.surfaceRaised, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: NzType.caption.copyWith(
          color: c.surfaceRaised,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

/// «المزيد» — حسابُ صاحب الجهاز ومعهدُه، وبقيّةُ الأبواب بعناوين القائمة
/// الجانبية نفسها، والخروج.
///
/// وهو جذرُ مكدّسٍ مستقلّ: البابُ يُفتح فوقه بزرّ رجوعٍ إليه، فيبقى الطريقُ إلى
/// الأبواب الأحد عشرَ الباقية ضغطتين.
class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.sections,
    required this.onOpen,
    this.pendingExcuses = 0,
  });

  final List<DesktopSection> sections;
  final ValueChanged<DesktopSection> onOpen;
  final int pendingExcuses;

  @override
  Widget build(BuildContext context) {
    final groups = <SectionGroup, List<DesktopSection>>{};

    for (final section in sections) {
      groups.putIfAbsent(section.group, () => []).add(section);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          NzSpace.s4,
          NzSpace.s4,
          NzSpace.s4,
          NzSpace.s6,
        ),
        children: [
          const _AccountCard(),
          for (final entry in groups.entries) ...[
            _GroupLabel(entry.key.label),
            _Group(
              children: [
                for (final section in entry.value)
                  _DoorTile(
                    icon: section.icon,
                    label: section.label,
                    badge: section.id == 'excuses' ? pendingExcuses : 0,
                    onTap: () => onOpen(section),
                  ),
              ],
            ),
          ],
          const _GroupLabel('حول'),
          _Group(
            children: [
              _DoorTile(
                icon: NzIcons.informationCircle,
                label: 'حول التطبيق',
                onTap: () => openAboutApp(context, AppConfig.about),
              ),
              _DoorTile(
                icon: NzIcons.star,
                label: 'حول المطوِّر',
                onTap: () => openAboutDeveloper(context),
              ),
            ],
          ),
          const _GroupLabel('الحساب'),
          const _Group(children: [_SignOutTile()]),
          const SizedBox(height: NzSpace.s5),
          Center(
            child: Text(
              '${Brand.name} · ${Brand.domain}',
              style: NzType.caption.copyWith(color: context.nz.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقةُ الحساب على أرضية الليل المنقوشة — العلامةُ ثم الاسمُ والمعهدُ والدورة،
/// ومبدّلُ المعاهد لمن له أكثرُ من واحد.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([deps.session, deps.institutes]),
      builder: (context, _) {
        final snapshot = deps.session.snapshot;
        final switcher = deps.institutes;

        return ClipRRect(
          borderRadius: BorderRadius.circular(NzRadius.md),
          child: NzPattern(
            scale: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(NzSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandGlyph(height: 44),
                      const SizedBox(width: NzSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot?.userName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NzType.title.copyWith(
                                color: NzBrand.star,
                                height: 1.4,
                              ),
                            ),
                            Text(
                              snapshot?.roles.map(roleLabelOf).join(' · ') ??
                                  '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NzType.caption.copyWith(
                                color: NzBrand.bronze,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NzSpace.s4),
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      NzSpace.s3,
                      NzSpace.s2,
                      NzSpace.s1,
                      NzSpace.s2,
                    ),
                    decoration: BoxDecoration(
                      color: NzBrand.nightRaised,
                      border: Border.all(color: NzBrand.nightLine),
                      borderRadius: BorderRadius.circular(NzRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const NzIcon(
                          NzIcons.mosque,
                          size: 20,
                          color: NzBrand.bronze,
                        ),
                        const SizedBox(width: NzSpace.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot?.institute.name ?? Brand.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NzType.body.copyWith(
                                  color: NzBrand.star,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                              Text(
                                snapshot?.courseName ?? 'لا دورةَ جارية',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NzType.caption.copyWith(
                                  color: NzColorTokens.dark.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (switcher.hasChoice)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: NzBrand.bronze,
                            ),
                            onPressed: () => _switch(context, deps),
                            child: const Text('بدّل'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _switch(BuildContext context, AppDependencies deps) async {
    final messenger = ScaffoldMessenger.of(context);
    final current = deps.session.snapshot?.institute.uuid;

    final chosen = await showModalBottomSheet<InstituteOption>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            NzSpace.s4,
            0,
            NzSpace.s4,
            NzSpace.s4,
          ),
          children: [
            Text(
              'بدّل المعهد',
              style: NzType.title.copyWith(color: context.nz.ink),
            ),
            const SizedBox(height: NzSpace.s1),
            Text(
              'التبديلُ يمسح مخزنَ هذا الجهاز ويسحب المعهدَ الجديد من الصفر — '
              'فقد يستغرق دقائق على معهدٍ قائمٍ منذ شهور.',
              style: NzType.caption.copyWith(color: context.nz.inkMuted),
            ),
            const SizedBox(height: NzSpace.s3),
            for (final option in deps.institutes.options)
              ListTile(
                leading: NzIcon(
                  option.uuid == current ? NzIcons.radioOn : NzIcons.radioOff,
                ),
                title: Text(option.name),
                subtitle: option.isActive ? null : const Text('موقوف'),
                onTap: option.uuid == current
                    ? null
                    : () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) {
      return;
    }

    try {
      await deps.institutes.switchTo(chosen.uuid);
    } on PendingWorkBlocksSwitch catch (blocked) {
      messenger.showSnackBar(SnackBar(content: Text(blocked.message)));
    } on Object catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(failure))));
    }
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        NzSpace.s1,
        NzSpace.s5,
        NzSpace.s1,
        NzSpace.s2,
      ),
      child: Text(
        label,
        style: NzType.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: context.nz.inkMuted,
        ),
      ),
    );
  }
}

/// بطاقةٌ بحدٍّ تجمع أبوابَ العائلة الواحدة، يفصل بينها خطّ.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(NzRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: c.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _DoorTile extends StatelessWidget {
  const _DoorTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.danger = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final fg = danger ? c.danger : c.ink;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NzSpace.s3,
            vertical: NzSpace.s2,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: danger ? c.dangerSoft : c.bronzeSoft,
                  borderRadius: BorderRadius.circular(NzRadius.sm),
                ),
                child: NzIcon(
                  icon,
                  size: 22,
                  color: danger ? c.danger : c.bronzeInk,
                ),
              ),
              const SizedBox(width: NzSpace.s3),
              Expanded(
                child: Text(
                  label,
                  style: NzType.body.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badge > 0) ...[
                _Badge(count: badge),
                const SizedBox(width: NzSpace.s2),
              ],
              if (!danger)
                NzIcon(NzIcons.chevronLeft, size: 18, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutTile extends StatelessWidget {
  const _SignOutTile();

  @override
  Widget build(BuildContext context) {
    return _DoorTile(
      icon: NzIcons.logout,
      label: 'تسجيل الخروج',
      danger: true,
      onTap: () => _confirm(context),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final session = AppScope.of(context).session;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'يُمسح مخزنُ هذا الجهاز عند الخروج، فما لم يُزامَن من كتاباتك يضيع. '
          'تأكّد أن شريطَ المزامنة لا يعرض عملياتٍ معلّقة.',
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
      await session.signOut();
    }
  }
}
