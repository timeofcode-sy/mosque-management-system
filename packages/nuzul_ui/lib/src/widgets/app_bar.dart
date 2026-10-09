import 'package:flutter/material.dart';

import '../generated/tokens.dart';
import '../icons.dart';
import '../mark.dart';
import '../theme.dart';

/// An action in [NzAppBar]: icon plus a label that is read out and shown as a tooltip.
class NzAction {
  const NzAction(this.icon, this.label, [this.onPressed]);

  final String icon;
  final String label;
  final VoidCallback? onPressed;
}

/// The top bar of every screen: the mark, the title in Reem Kufi, a subtitle, at most two actions.
class NzAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NzAppBar({super.key, required this.title, this.subtitle, this.actions = const [], this.showMark = true});

  final String title;
  final String? subtitle;
  final List<NzAction> actions;

  /// Hide below the first level, where a back action takes the mark's place.
  final bool showMark;

  @override
  Size get preferredSize => const Size.fromHeight(NzSize.appbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: NzSpace.s4,
      title: Row(children: [
        if (showMark) ...[const NzMark(height: 40), const SizedBox(width: NzSpace.s3)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Text(subtitle!, style: NzType.caption.copyWith(color: c.inkMuted)),
          ]),
        ),
      ]),
      actions: [
        for (final a in actions)
          IconButton(onPressed: a.onPressed ?? () {}, tooltip: a.label, icon: NzIcon(a.icon, size: 22, semanticLabel: a.label)),
        const SizedBox(width: NzSpace.s2),
      ],
    );
  }
}
