import 'package:flutter/material.dart';

import '../digits.dart';
import '../generated/tokens.dart';
import '../icons.dart';
import '../mark.dart';
import '../theme.dart';

/// A top-level destination. Destinations with a [section] start a titled group in the side navigation.
class NzDestination {
  const NzDestination({required this.icon, required this.label, this.count, this.section});

  final String icon;
  final String label;
  final int? count;
  final String? section;
}

/// The window-size class of the breakpoint tokens.
enum NzWindow {
  compact,
  medium,
  expanded;

  static NzWindow of(double width) => width >= NzBreakpoint.expanded
      ? NzWindow.expanded
      : width >= NzBreakpoint.medium
          ? NzWindow.medium
          : NzWindow.compact;
}

/// One scaffold for every platform. Under 600px: bottom navigation (first five destinations).
/// 600–1023px: navigation rail. 1024px and up: the full side navigation with sections and counts.
class NzAdaptiveScaffold extends StatelessWidget {
  const NzAdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.place,
    this.footer,
    this.bottomBar,
  });

  final List<NzDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;

  /// The mosque or institute, shown under the name in the side navigation.
  final String? place;

  /// Sync state or account line at the foot of the side navigation.
  final String? footer;

  /// A bar pinned under the body (e.g. «حفظ الحضور»), above the bottom navigation on phones.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final window = NzWindow.of(MediaQuery.sizeOf(context).width);
    final content = Column(children: [Expanded(child: body), if (bottomBar != null) bottomBar!]);
    switch (window) {
      case NzWindow.compact:
        final shown = destinations.take(5).toList();
        return Scaffold(
          appBar: appBar,
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex.clamp(0, shown.length - 1),
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final d in shown) NavigationDestination(icon: NzIcon(d.icon), label: d.label),
            ],
          ),
        );
      case NzWindow.medium:
        return Scaffold(
          appBar: appBar,
          body: Row(children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              leading: const Padding(padding: EdgeInsets.only(bottom: NzSpace.s4), child: NzMark(height: 40)),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: NzIcon(d.icon), label: Text(d.label)),
              ],
            ),
            VerticalDivider(width: 1, color: c.line),
            Expanded(child: content),
          ]),
        );
      case NzWindow.expanded:
        return Scaffold(
          body: Row(children: [
            NzSideNav(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              place: place,
              footer: footer,
            ),
            Expanded(child: Column(children: [if (appBar != null) appBar!, Expanded(child: content)])),
          ]),
        );
    }
  }
}

/// Side navigation for desktop and the web app (≥ 1024px), on the start side (right in Arabic).
class NzSideNav extends StatelessWidget {
  const NzSideNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.place,
    this.footer,
  });

  final List<NzDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? place;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final items = <Widget>[];
    for (var i = 0; i < destinations.length; i++) {
      final d = destinations[i];
      if (d.section != null) {
        items.add(Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(NzSpace.s3, NzSpace.s4, NzSpace.s3, NzSpace.s1),
          child: Text(d.section!, style: NzType.caption.copyWith(fontWeight: FontWeight.w600, color: c.inkMuted)),
        ));
      }
      final on = i == selectedIndex;
      final fg = on ? c.bronzeInk : c.ink;
      items.add(Semantics(
        selected: on,
        button: true,
        child: Material(
          color: on ? c.bronzeSoft : const Color(0x00000000),
          borderRadius: BorderRadius.circular(NzRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(NzRadius.sm),
            onTap: () => onDestinationSelected(i),
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s3),
                child: Row(children: [
                  NzIcon(d.icon, size: 22, color: fg),
                  const SizedBox(width: NzSpace.s3),
                  Expanded(
                    child: Text(d.label,
                        style: NzType.label.copyWith(
                            fontSize: 14, color: fg, fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
                  ),
                  if (d.count != null)
                    Text(nzDigits(d.count!), style: NzType.caption.copyWith(color: c.inkMuted)),
                ]),
              ),
            ),
          ),
        ),
      ));
    }
    return Container(
      width: NzSize.sidenavWidth,
      decoration: BoxDecoration(color: c.surfaceRaised, border: BorderDirectional(end: BorderSide(color: c.line))),
      padding: const EdgeInsets.symmetric(horizontal: NzSpace.s3, vertical: NzSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(NzSpace.s2, NzSpace.s1, NzSpace.s2, NzSpace.s4),
          child: Row(children: [
            const NzMark(height: 46),
            const SizedBox(width: NzSpace.s3),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('نزلاً', style: NzType.display3.copyWith(fontSize: 24, height: 30 / 24, color: c.ink)),
              if (place != null) Text(place!, style: NzType.caption.copyWith(color: c.inkMuted)),
            ]),
          ]),
        ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: items)),
        if (footer != null) ...[
          Divider(color: c.line),
          Padding(
            padding: const EdgeInsets.all(NzSpace.s3),
            child: Text(footer!, style: NzType.caption.copyWith(color: c.inkMuted)),
          ),
        ],
      ]),
    );
  }
}
