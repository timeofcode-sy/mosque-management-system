import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

void main() {
  test('digits stay Latin (0-9): the system never writes Arabic-Indic digits', () {
    expect(nzDigits(2026), '2026');
    expect(nzDigits('الجزء 18'), 'الجزء 18');
  });

  test('text tokens keep 4.5:1 on their grounds in both themes', () {
    double ratio(Color a, Color b) {
      final l = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (l[1] + 0.05) / (l[0] + 0.05);
    }

    for (final t in [NzColorTokens.light, NzColorTokens.dark]) {
      expect(ratio(t.ink, t.surface), greaterThanOrEqualTo(4.5));
      expect(ratio(t.inkMuted, t.surfaceRaised), greaterThanOrEqualTo(4.5));
      expect(ratio(t.onPrimary, t.primary), greaterThanOrEqualTo(4.5));
      expect(ratio(t.success, t.successSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.danger, t.dangerSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.focus, t.surface), greaterThanOrEqualTo(3));
    }
  });

  testWidgets('navigation adapts: bar on phones, rail on tablets, side navigation on desktop', (tester) async {
    Widget app() => MaterialApp(
          theme: NuzulTheme.light(),
          locale: const Locale('ar'),
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: NzAdaptiveScaffold(
            destinations: const [
              NzDestination(icon: NzIcons.home, label: 'اليوم'),
              NzDestination(icon: NzIcons.students, label: 'الطلاب', section: 'الحلقات'),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            body: const SizedBox.expand(),
          ),
        );

    Future<void> size(double w, double h) async {
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    await size(390, 844);
    await tester.pumpWidget(app());
    expect(find.byType(NavigationBar), findsOneWidget);

    await size(800, 1100);
    await tester.pumpWidget(app());
    expect(find.byType(NavigationRail), findsOneWidget);

    await size(1440, 900);
    await tester.pumpWidget(app());
    expect(find.byType(NzSideNav), findsOneWidget);
  });
}
