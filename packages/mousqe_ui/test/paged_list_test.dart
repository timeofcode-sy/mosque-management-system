import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

Widget host(Widget child) => MousqeApp(
      theme: MousqeTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('PaginationBar window', () {
    List<int?> window(int page, int total, {int size = 25}) => PaginationBar(
          page: page,
          pageSize: size,
          total: total,
          onPage: (_) {},
        ).window;

    test('keeps the first, the last and the neighbours, with ellipses between', () {
      // 243 صفاً بـ 25 = 10 صفحات (0..9).
      expect(window(0, 243), [0, 1, null, 9]);
      expect(window(4, 243), [0, null, 3, 4, 5, null, 9]);
      expect(window(9, 243), [0, null, 8, 9]);
    });

    test('shows every page when there are few', () {
      expect(window(1, 60), [0, 1, 2]);
    });
  });

  testWidgets('a list is cut into pages and the summary says what is shown', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(PagedList<int>(
      items: List.generate(60, (i) => i + 1),
      itemBuilder: (context, item) => Text('صف $item'),
    )));

    expect(find.text('صف 1'), findsOneWidget);
    expect(find.text('صف 25'), findsOneWidget);
    expect(find.text('صف 26'), findsNothing);
    expect(find.textContaining('1–25'), findsOneWidget);

    await tester.tap(find.byTooltip('التالي'));
    await tester.pump();

    expect(find.text('صف 1'), findsNothing);
    expect(find.text('صف 26'), findsOneWidget);
    expect(find.textContaining('26–50'), findsOneWidget);

    await tester.tap(find.byTooltip('الصفحة 3'));
    await tester.pump();

    expect(find.text('صف 60'), findsOneWidget);
    expect(find.textContaining('51–60'), findsOneWidget);
  });

  testWidgets('changing the reset key returns to the first page', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget list(String query, List<int> items) => host(PagedList<int>(
          items: items,
          resetKey: query,
          itemBuilder: (context, item) => Text('صف $item'),
        ));

    await tester.pumpWidget(list('', List.generate(60, (i) => i + 1)));
    await tester.tap(find.byTooltip('التالي'));
    await tester.pump();
    expect(find.text('صف 26'), findsOneWidget);

    await tester.pumpWidget(list('بحث', List.generate(40, (i) => i + 1)));
    expect(find.text('صف 1'), findsOneWidget);
    expect(find.textContaining('1–25'), findsOneWidget);
  });

  testWidgets('a short list has no page buttons, only the summary', (tester) async {
    await tester.pumpWidget(host(PagedList<int>(
      items: const [1, 2, 3],
      itemBuilder: (context, item) => Text('صف $item'),
    )));

    expect(find.byTooltip('التالي'), findsNothing);
    expect(find.textContaining('1–3'), findsOneWidget);
  });
}
