import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../brand/brand.dart';

/// غلافُ `MaterialApp` تصدّره الحزمة — `ar` اللغة الوحيدة، RTL مضبوطة، وأرقام لاتينية (0–9)،
/// وسمتان (فاتحة وليلية) تتبعان نظام الجهاز.
class MousqeApp extends StatelessWidget {
  const MousqeApp({
    super.key,
    required this.home,
    required this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
    this.title = Brand.name,
  });

  final Widget home;
  final ThemeData theme;

  /// السمةُ الليلية — تُتَّبع من نظام الجهاز ما لم يُحدَّد [themeMode].
  final ThemeData? darkTheme;
  final ThemeMode themeMode;

  /// ما يقرؤه النظامُ اسماً للنافذة — بطاقةُ التطبيق في قائمة المهامّ على أندرويد.
  final String title;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: title,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    );
  }
}
