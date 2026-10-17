import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

void main() {
  testWidgets('dark mode and a larger font apply app-wide and are saved', (
    tester,
  ) async {
    String? saved;
    final appearance = AppearanceController(
      read: () async => saved,
      write: (value) async => saved = value,
    );

    late BuildContext inner;
    await tester.pumpWidget(
      MousqeApp(
        theme: MousqeTheme.light(),
        darkTheme: MousqeTheme.dark(),
        appearance: appearance,
        home: Builder(
          builder: (context) {
            inner = context;

            return const Scaffold(
              body: AboutLinks(
                app: AboutAppInfo(title: 't', summary: 's'),
              ),
            );
          },
        ),
      ),
    );

    expect(Theme.of(inner).brightness, Brightness.light);

    await tester.tap(find.text('المظهر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('داكن'));
    await tester.tap(find.text('كبير'));
    await tester.pumpAndSettle();

    expect(Theme.of(inner).brightness, Brightness.dark);
    expect(MediaQuery.textScalerOf(inner).scale(10), closeTo(11.5, 0.001));
    expect(saved, contains('"mode":"dark"'));

    // تطبيقٌ يُفتح من جديد يقرأ الاختيارَ المحفوظ.
    final reopened = AppearanceController(read: () async => saved);
    await reopened.load();
    expect(reopened.mode, ThemeMode.dark);
    expect(reopened.scale, 1.15);
  });

  test('a broken file falls back to the defaults', () async {
    final appearance = AppearanceController(read: () async => '{not json');
    await appearance.load();

    expect(appearance.mode, ThemeMode.system);
    expect(appearance.scale, 1.0);
  });
}
