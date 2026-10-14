import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

void main() {
  testWidgets('BrandMark announces the system name', (tester) async {
    await tester.pumpWidget(
      MousqeApp(theme: MousqeTheme.light(), home: const BrandMark()),
    );

    expect(find.bySemanticsLabel(Brand.name), findsOneWidget);
  });

  group('SplashGate', () {
    Widget gate({required bool ready}) => MousqeApp(
          theme: MousqeTheme.light(),
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

      await tester.pump(const Duration(milliseconds: 1900));
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

  group('server choice', () {
    Future<void> pumpSplash(
      WidgetTester tester, {
      required ServerChoice choice,
      bool ready = true,
    }) async {
      await tester.pumpWidget(
        MousqeApp(
          theme: MousqeTheme.light(),
          home: SplashGate(
            ready: ready,
            caption: 'تطبيق الأستاذ',
            onServerChoice: (context) => showServerChoiceDialog(context, choice),
            child: const Text('الشاشة الأولى'),
          ),
        ),
      );
    }

    // دون pumpAndSettle: مؤشّرُ التحميل في الشاشة يدور بلا نهاية ما دامت قائمة.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> tapLogo(WidgetTester tester, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tap(find.byType(BrandGlyph));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    ServerChoice choice({
      List<(bool, String)>? applied,
      Future<void> Function(bool, String)? apply,
    }) {
      return ServerChoice(
        primaryHost: 'nuzuln.com',
        usesPrimary: true,
        localAddress: '',
        warning: 'سيُخرجك من حسابك.',
        validateLocal: (value) => value.trim().isEmpty ? 'اكتب العنوان' : null,
        check: (primary, local) async => null,
        apply: apply ?? (primary, local) async => applied?.add((primary, local)),
      );
    }

    testWidgets('two taps open nothing', (tester) async {
      await pumpSplash(tester, choice: choice());

      await tapLogo(tester, 2);

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('three taps open the dialog on the primary server', (tester) async {
      await pumpSplash(tester, choice: choice());

      await tapLogo(tester, 3);
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('nuzuln.com'), findsOneWidget);
      expect(find.text('خادم محلّي'), findsOneWidget);
      expect(find.text('سيُخرجك من حسابك.'), findsOneWidget);
      // حقلُ العنوان لا يظهر إلا مع الخيار المحلّي.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('taps further apart than the window do not add up', (tester) async {
      // الجلسةُ لم تجهز: وإلا انسحبت الشاشةُ في الفاصل فلا يبقى شعارٌ يُنقر.
      await pumpSplash(tester, choice: choice(), ready: false);

      await tapLogo(tester, 2);
      await tester.pump(SplashGate.tapWindow + const Duration(milliseconds: 100));
      await tapLogo(tester, 1);

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('holds the splash even when the session is ready', (tester) async {
      await pumpSplash(tester, choice: choice());

      // تجاوزُ الحدّ الأدنى (ثانيتان) بنقراتٍ بدأت قبله، كلٌّ منها داخل نافذة سابقتها.
      await tapLogo(tester, 1);
      await tester.pump(const Duration(milliseconds: 1200));
      await tapLogo(tester, 1);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(BrandSplash), findsOneWidget);

      await tapLogo(tester, 1);
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('الشاشة الأولى'), findsNothing);
    });

    testWidgets('lets go once the dialog is closed', (tester) async {
      await pumpSplash(tester, choice: choice());

      await tapLogo(tester, 3);
      await settle(tester);
      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      // ما بقي من الحدّ الأدنى (ثانيتان)، ثم التلاشي.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('الشاشة الأولى'), findsOneWidget);
    });

    testWidgets('a local choice needs an address before it saves', (tester) async {
      final applied = <(bool, String)>[];
      await pumpSplash(tester, choice: choice(applied: applied));

      await tapLogo(tester, 3);
      await settle(tester);
      await tester.tap(find.text('خادم محلّي'));
      await settle(tester);
      await tester.tap(find.text('حفظ'));
      await settle(tester);

      expect(find.text('اكتب العنوان'), findsOneWidget);
      expect(applied, isEmpty);

      await tester.enterText(find.byType(TextField), '192.168.1.10:8000');
      await tester.tap(find.text('حفظ'));
      await settle(tester);

      expect(applied, [(false, '192.168.1.10:8000')]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows why a switch was refused and stays open', (tester) async {
      await pumpSplash(
        tester,
        choice: choice(
          apply: (primary, local) async => throw StateError('بقيت 3 عمليات'),
        ),
      );

      await tapLogo(tester, 3);
      await settle(tester);
      await tester.tap(find.text('حفظ'));
      await settle(tester);

      expect(find.textContaining('بقيت 3 عمليات'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
