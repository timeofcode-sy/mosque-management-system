import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

void main() {
  testWidgets('the logo ships inside the package bundle', (tester) async {
    // سطرُ assets ناقصٌ في pubspec لا يكسر البناء ولا التحليل — يكسر الشاشةَ وحدها.
    final bytes = await rootBundle.load(
      'packages/mousqe_ui/assets/brand/nuzuln_mark.png',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });

  testWidgets('BrandMark announces the system name', (tester) async {
    await tester.pumpWidget(
      MousqeApp(theme: MousqeTheme.fallback(), home: const BrandMark()),
    );

    expect(find.bySemanticsLabel(Brand.name), findsOneWidget);
  });

  group('SplashGate', () {
    Widget gate({required bool ready}) => MousqeApp(
          theme: MousqeTheme.fallback(),
          home: SplashGate(
            ready: ready,
            caption: 'تطبيق الأستاذ',
            child: const Text('الشاشة الأولى'),
          ),
        );

    testWidgets('holds the splash for the minimum even when ready at once',
        (tester) async {
      await tester.pumpWidget(gate(ready: true));
      expect(find.byType(BrandSplash), findsOneWidget);
      expect(find.text('تطبيق الأستاذ'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('الشاشة الأولى'), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(BrandSplash), findsNothing);
      expect(find.text('الشاشة الأولى'), findsOneWidget);
    });

    testWidgets('outlasts the minimum while the session is still restoring',
        (tester) async {
      await tester.pumpWidget(gate(ready: false));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(BrandSplash), findsOneWidget);

      await tester.pumpWidget(gate(ready: true));
      // دون pumpAndSettle: مؤشّرُ التحميل يدور بلا نهاية ما دامت الشاشةُ قائمة.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BrandSplash), findsNothing);
      expect(find.text('الشاشة الأولى'), findsOneWidget);
    });
  });
}
