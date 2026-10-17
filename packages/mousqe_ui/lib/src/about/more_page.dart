import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

import '../theme/appearance.dart';
import '../update/update_gate.dart';
import '../update/update_screen.dart';
import '../widgets/confirm_dialog.dart';
import 'about_screens.dart';

/// بندٌ يضيفه التطبيقُ إلى «المزيد» فوق بنود التطبيق الثابتة — «أعذار الغياب» لوليّ الأمر.
class MoreEntry {
  const MoreEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

/// لسانُ «المزيد» في الشريط السفلي: صاحبُ الحساب، ثم بنودُ التطبيق، ثم المظهرُ والتحديثُ
/// و«حول»، والخروجُ آخرَها بتأكيد.
///
/// كان كلُّ هذا في قائمة ⋮ صغيرة في شريط التطبيق؛ وفي التطبيقات ذات الشريط السفلي صار
/// صفحةً تُقرأ: البنودُ بأيقوناتها وشرحها، والخروجُ بعيدٌ عن الإصبع لا تحت زرّ الحول.
class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.app,
    required this.userName,
    required this.onSignOut,
    this.subtitle,
    this.entries = const [],
  });

  final AboutAppInfo app;
  final String userName;

  /// تحت الاسم: المعهدُ والصفة («معهد النور · طالب»).
  final String? subtitle;
  final List<MoreEntry> entries;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final updates = AppUpdateScope.read(context) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: NzSpace.s6),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(NzSpace.s4, NzSpace.s4, NzSpace.s4, NzSpace.s2),
            child: Padding(
              padding: const EdgeInsets.all(NzSpace.s4),
              child: Row(
                spacing: NzSpace.s3,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: c.bronzeSoft,
                    foregroundColor: c.bronzeInk,
                    child: Text(
                      userName.isEmpty ? '؟' : userName.characters.first,
                      style: NzType.title.copyWith(color: c.bronzeInk),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(userName, style: NzType.title.copyWith(color: c.ink)),
                        if (subtitle != null)
                          Text(subtitle!, style: NzType.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (entries.isNotEmpty)
            _Group(
              children: [
                for (final entry in entries)
                  _Tile(
                    icon: entry.icon,
                    label: entry.label,
                    subtitle: entry.subtitle,
                    onTap: entry.onTap,
                  ),
              ],
            ),
          _Group(
            children: [
              _Tile(
                icon: NzIcons.sun,
                label: 'المظهر',
                subtitle: 'الوضع الليلي وحجم الخط',
                onTap: () => showAppearanceSheet(context),
              ),
              if (updates)
                _Tile(
                  icon: NzIcons.download,
                  label: 'التحقق من التحديثات',
                  onTap: () => openUpdateScreen(context),
                ),
            ],
          ),
          _Group(
            children: [
              _Tile(
                icon: NzIcons.informationCircle,
                label: 'حول التطبيق',
                onTap: () => openAboutApp(context, app),
              ),
              _Tile(
                icon: NzIcons.user,
                label: 'حول المطوِّر',
                onTap: () => openAboutDeveloper(context),
              ),
            ],
          ),
          _Group(
            children: [
              _Tile(
                icon: NzIcons.logout,
                label: 'تسجيل الخروج',
                danger: true,
                onTap: () async {
                  if (await confirmSignOut(context)) {
                    await onSignOut();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(NzSpace.s4, NzSpace.s2, NzSpace.s4, NzSpace.s2),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final String icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final color = danger ? c.danger : c.ink;

    return ListTile(
      leading: NzIcon(icon, color: danger ? c.danger : c.bronzeInk),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: danger ? null : NzIcon(NzIcons.chevronLeft, size: 18, color: c.inkMuted),
      onTap: onTap,
    );
  }
}
