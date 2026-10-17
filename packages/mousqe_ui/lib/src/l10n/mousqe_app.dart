import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../brand/brand.dart';
import '../theme/appearance.dart';

/// غلافُ `MaterialApp` تصدّره الحزمة — `ar` اللغة الوحيدة، RTL مضبوطة، وأرقام لاتينية (0–9)،
/// وسمتان (فاتحة وليلية).
///
/// والمظهرُ لصاحب الجهاز ([AppearanceController]): الوضعُ تلقائيٌّ يتبع النظام ما لم يختر
/// فاتحاً أو داكناً، وحجمُ الخط معاملٌ يُضرب في مقاس النظام فيكبّر كلَّ نصٍّ في التطبيق.
class MousqeApp extends StatefulWidget {
  const MousqeApp({
    super.key,
    required this.home,
    required this.theme,
    this.darkTheme,
    this.themeMode,
    this.appearance,
    this.title = Brand.name,
  });

  final Widget home;
  final ThemeData theme;

  /// السمةُ الليلية.
  final ThemeData? darkTheme;

  /// وضعٌ مفروض يتجاوز اختيارَ صاحب الجهاز — للاختبارات.
  final ThemeMode? themeMode;

  /// اختيارُ صاحب الجهاز محفوظاً — وإن غاب فمظهرٌ في الذاكرة لا يُحفظ.
  final AppearanceController? appearance;

  /// ما يقرؤه النظامُ اسماً للنافذة — بطاقةُ التطبيق في قائمة المهامّ على أندرويد.
  final String title;

  @override
  State<MousqeApp> createState() => _MousqeAppState();
}

class _MousqeAppState extends State<MousqeApp> {
  late final AppearanceController _fallback = AppearanceController();

  AppearanceController get _appearance => widget.appearance ?? _fallback;

  @override
  void dispose() {
    _fallback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Appearance(
      controller: _appearance,
      child: ListenableBuilder(
        listenable: _appearance,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: widget.title,
          theme: widget.theme,
          darkTheme: widget.darkTheme,
          themeMode: widget.themeMode ?? _appearance.mode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final media = MediaQuery.of(context);
            // مقاسُ النظام × اختيارُ صاحب الجهاز، بسقفٍ يحفظ التخطيطَ من الانكسار.
            final factor = (media.textScaler.scale(1) * _appearance.scale)
                .clamp(0.8, 2.0);

            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(factor)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: widget.home,
        ),
      ),
    );
  }
}
