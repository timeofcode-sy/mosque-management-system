import 'package:flutter/material.dart';

/// نظير `App\Support\InstituteTheme` — نفس النسب على نفس الألوان الثلاثة
/// القادمة في `/bootstrap`. الخوارزمية خلطٌ خطّيٌّ في sRGB نحو الأبيض
/// للفواتح ونحو الأسود للدواكن، بنسبٍ ثابتة (BRAND · GOLD · SAND).
///
/// معهدٌ لم يضبط ألوانه يعود بلوحة `design/design-tokens.json` الافتراضية —
/// القيم منسوخة حرفياً كـ Dart consts، لا إعادة اشتقاق من ملف JSON في زمن
/// التشغيل لتفادي حزمة تحليل JSON إضافية لأربعة أرقام ثابتة.
class MousqeTheme {
  const MousqeTheme._();

  static const defaultPrimary = '#0F5132'; // brand-600
  static const defaultSecondary = '#C9A227'; // gold-500
  static const defaultSurface = '#F7F3EA'; // sand-100

  static const Map<int, double> _brandRatios = {
    50: 0.92,
    100: 0.84,
    200: 0.68,
    300: 0.50,
    400: 0.30,
    500: 0.14,
    600: 0.0,
    700: -0.15,
    800: -0.32,
    900: -0.50,
  };

  static const Map<int, double> _goldRatios = {
    300: 0.40,
    400: 0.20,
    500: 0.0,
    600: -0.18,
    700: -0.36,
  };

  static const Map<int, double> _sandRatios = {
    50: 0.55,
    100: 0.0,
    200: -0.06,
    300: -0.16,
  };

  /// سلّم التدرّج الكامل (50→900 حسب النطاق) مشتقّاً من لون أساسي واحد.
  static Map<int, Color> shades(String hex, Map<int, double> ratios) {
    final base = _parseHex(hex);
    return {
      for (final entry in ratios.entries) entry.key: _shade(base, entry.value),
    };
  }

  /// ثيمٌ كامل من ثلاثة ألوان اعتباطية — نظير `InstituteTheme::for()`.
  static ThemeData fromColors({
    required String primary,
    required String secondary,
    required String surface,
  }) {
    final brand = shades(primary, _brandRatios);
    final gold = shades(secondary, _goldRatios);
    final sand = shades(surface, _sandRatios);

    final colorScheme = ColorScheme.light(
      primary: brand[600]!,
      onPrimary: sand[50] ?? Colors.white,
      secondary: gold[500]!,
      onSecondary: brand[900] ?? Colors.black,
      surface: sand[100]!,
      onSurface: brand[900] ?? Colors.black,
    );

    return _build(colorScheme);
  }

  /// ثيمٌ افتراضي مطابق لـ `design/design-tokens.json` بلا ألوان معهد.
  static ThemeData fallback() {
    return fromColors(
      primary: defaultPrimary,
      secondary: defaultSecondary,
      surface: defaultSurface,
    );
  }

  static ThemeData _build(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'IBM Plex Sans Arabic',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: 'Reem Kufi'),
        headlineMedium: TextStyle(fontFamily: 'Reem Kufi'),
        headlineSmall: TextStyle(fontFamily: 'Reem Kufi'),
        titleLarge: TextStyle(fontFamily: 'Reem Kufi'),
      ),
    );
  }

  /// لونٌ ممزوجٌ نحو الأبيض (نسبة موجبة) أو نحو الأسود (سالبة) — نظير
  /// `InstituteTheme::shade()`.
  static Color _shade(Color base, double ratio) {
    final target = ratio >= 0 ? 255 : 0;
    final weight = ratio.abs();

    int mix(int channel) => (channel + (target - channel) * weight).round();

    final r = (base.r * 255).round();
    final g = (base.g * 255).round();
    final b = (base.b * 255).round();

    return Color.fromARGB(255, mix(r), mix(g), mix(b));
  }

  static Color _parseHex(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final value = int.parse(normalized, radix: 16);
    return Color(0xFF000000 | value);
  }
}
