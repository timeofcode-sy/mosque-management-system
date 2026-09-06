import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// غلافُ `MaterialApp` تصدّره الحزمة — `ar` اللغة الوحيدة في 5.2، RTL مضبوطة،
/// وأرقام لاتينية بلا أرقام هندية (`MaterialLocalizations` الافتراضية).
class MousqeApp extends StatelessWidget {
  const MousqeApp({
    super.key,
    required this.home,
    required this.theme,
  });

  final Widget home;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
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
