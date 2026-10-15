import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _app = AboutAppInfo(title: 'نزلاً', summary: 'تطبيقُ الهاتف للاختبار.');

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'nuzuln',
      packageName: 'com.timeofcode.nuzuln',
      version: '1.0.0-beta.4',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  Widget host({ThemeData? theme}) => MousqeApp(
        theme: theme ?? MousqeTheme.light(),
        home: Scaffold(
          appBar: AppBar(actions: const [AboutMenuButton(app: _app)]),
          body: const AboutLinks(app: _app),
        ),
      );

  testWidgets('the app bar menu opens the app page with its version and owner', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byTooltip('حول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حول التطبيق').last);
    await tester.pumpAndSettle();

    expect(find.byType(AboutAppScreen), findsOneWidget);
    expect(find.text('تطبيقُ الهاتف للاختبار.'), findsOneWidget);
    // أرقامٌ لاتينية كما يُكتب كلُّ رقمٍ في النظام، والنسخةُ معزولةٌ فلا ينقلبُ ترتيبُها.
    expect(find.text('الإصدار \u20661.0.0-beta.4\u2069 · بناء 4'), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining('جميع الحقوق محفوظة'), 200);
    expect(find.textContaining(Developer.name), findsWidgets);
  });

  testWidgets('the app page lists technical support, and a tap offers call or WhatsApp', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('حول التطبيق'));
    await tester.pumpAndSettle();

    expect(find.text('الدعم الفني والتقني'), findsOneWidget);
    for (final person in TechnicalSupport.contacts) {
      expect(find.text(person.name), findsOneWidget);
      expect(find.text(person.phone), findsOneWidget);
    }

    await tester.tap(find.text(TechnicalSupport.contacts.first.name));
    await tester.pumpAndSettle();

    expect(find.text('اتصال'), findsOneWidget);
    expect(find.text('مراسلة عبر واتساب'), findsOneWidget);
    expect(find.text('نسخ الرقم'), findsOneWidget);
  });

  test('support links dial and message the same number that is shown', () {
    const person = SupportContact(name: 'x', phone: '+963 964 630 090');

    expect(person.telUri, 'tel:+963964630090');
    expect(person.whatsappUri, 'https://wa.me/963964630090');
  });

  testWidgets('the app page leads to the developer page with every contact', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('حول التطبيق'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('حول المطوِّر'), 200);
    await tester.tap(find.text('حول المطوِّر'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutDeveloperScreen), findsOneWidget);
    expect(find.text(Developer.arabicName), findsOneWidget);

    for (final contact in Developer.contacts) {
      await tester.scrollUntilVisible(find.text(contact.label), 200);
      expect(find.text(contact.label), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text(Developer.address), 200);
  });

  testWidgets('the app page offers privacy and terms instead of the licenses, each a full document', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('حول التطبيق'));
    await tester.pumpAndSettle();

    expect(find.text('تراخيص البرمجيات مفتوحة المصدر'), findsNothing);

    for (final document in [Legal.privacy, Legal.terms]) {
      final entry = document == Legal.privacy ? 'الخصوصية' : 'الشروط والأحكام';
      await tester.scrollUntilVisible(find.text(entry), 200);
      await tester.ensureVisible(find.text(entry));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();

      expect(find.byType(LegalScreen), findsOneWidget);
      expect(find.text(document.title), findsOneWidget);
      await tester.scrollUntilVisible(find.text(document.updated), 400);
      expect(find.text('${document.sections.length}. التواصل معنا'), findsOneWidget);

      Navigator.of(tester.element(find.byType(LegalScreen))).pop();
      await tester.pumpAndSettle();
    }

    // The licenses some components require now sit at the end of the terms.
    expect(Legal.terms.showLicenses, isTrue);
    expect(Legal.privacy.showLicenses, isFalse);
  });

  testWidgets('the developer page builds on the night theme too', (tester) async {
    await tester.pumpWidget(host(theme: MousqeTheme.dark()));

    await tester.tap(find.text('حول المطوِّر'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(Developer.services.first), findsOneWidget);
  });

  test('every contact opens somewhere real, and the phone is the WhatsApp number', () {
    for (final contact in Developer.contacts) {
      expect(Uri.tryParse(contact.uri)?.hasScheme, isTrue, reason: contact.label);
    }

    final phone = Developer.contacts.firstWhere((c) => c.kind == ContactKind.phone);
    final whatsapp = Developer.contacts.firstWhere((c) => c.kind == ContactKind.whatsapp);
    expect(phone.uri.replaceAll(RegExp(r'\D'), ''), whatsapp.uri.replaceAll(RegExp(r'\D'), ''));
  });
}
