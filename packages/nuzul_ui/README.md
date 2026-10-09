# nuzul_ui

حزمة Flutter لهوية «نزلاً» (الإصدار الثالث): الرموز، والسمة الفاتحة والليلية، والخطوط (Reem Kufi وIBM Plex Sans Arabic وAmiri)، والأيقونات، والشعار، ومكوّنات الحلقة. حزمة واحدة لتطبيق الموبايل وبرنامج سطح المكتب وتطبيق الويب، بلا أي اعتماديات خارجية.

```dart
MaterialApp(
  theme: NuzulTheme.light(density: NuzulTheme.densityFor(defaultTargetPlatform)),
  darkTheme: NuzulTheme.dark(density: NuzulTheme.densityFor(defaultTargetPlatform)),
  locale: const Locale('ar', 'SY'),
  supportedLocales: const [Locale('ar', 'SY')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: const HomeShell(), // ابنها بـ NzAdaptiveScaffold
);
```

- `example/`: شاشات مرجعية (اليوم، الحضور، التسميع، لوحة الإشراف). شغّل `flutter create .` داخلها لإضافة المنصات، ثم `flutter run -d windows` أو `-d chrome` أو على الجوال.
- `test/`: اختبارات السلوك والتباين، وصور مرجعية للشاشات في `test/goldens`.
- `lib/src/generated/`: مولَّد من `tokens.json` في نظام التصميم. لا تعدّله يدويًا.

الخطوط مرخّصة برخصة SIL Open Font License، وتراخيصها في `fonts/`.
