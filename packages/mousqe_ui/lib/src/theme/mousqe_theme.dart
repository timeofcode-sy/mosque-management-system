import 'package:flutter/material.dart';

/// نظير `App\Support\InstituteTheme` — نفس النسب على نفس الألوان الثلاثة
/// القادمة في `/bootstrap`. الخوارزمية خلطٌ خطّيٌّ في sRGB نحو الأبيض
/// للفواتح ونحو الأسود للدواكن، بنسبٍ ثابتة (BRAND · GOLD · SAND).
///
/// معهدٌ لم يضبط ألوانه يعود بلوحة `design/design-tokens.json` الافتراضية —
/// القيم منسوخة حرفياً كـ Dart consts، لا إعادة اشتقاق من ملف JSON في زمن
/// التشغيل لتفادي حزمة تحليل JSON إضافية لأربعة أرقام ثابتة.
///
/// 🔄 م.5.3 — **الخلفيةُ بيضاءُ دائماً.** كان `surface` يُسنَد خاماً إلى
/// `scaffoldBackgroundColor`، فصارت الصفحةُ كلُّها بلون المعهد الثالث: نصٌّ داكنُ
/// الحمرة على خردلٍ مشبع، وبطاقاتٌ وحواراتٌ تذوب في خلفيتها لأنها من لونها.
/// صار `surface` **مصدرَ حرارةٍ لا طلاءَ صفحة**: يُخلط 92% نحو الأبيض للصفحة،
/// وتُشتقّ منه طبقاتُ `surfaceContainer*` بنسبٍ متدرّجة، فتنفصل البطاقةُ عن أرضيّتها
/// مهما أشبع المعهدُ لونَه — وتبقى هويتُه محسوسةً في دفء البياض.
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

  /// سلالمُ الأسطح المشتقّة من لون المعهد الثالث — كلُّها قريبةٌ من الأبيض.
  ///
  /// الفروقُ بينها صغيرةٌ عمداً (6% بين الطبقة والتي تليها): ما يفصل البطاقةَ عن
  /// الصفحة هو الحدُّ والظلّ، والتدرّجُ يسندهما ولا ينوب عنهما. وتوسيعُ الفروق يعيد
  /// المشكلةَ نفسها بدرجةٍ أخفّ — أسطحٌ ملوّنة بدل أسطحٍ بيضاء دافئة.
  static const double _pageTint = 0.92;
  static const double _containerLowTint = 0.88;
  static const double _containerTint = 0.82;
  static const double _containerHighTint = 0.74;
  static const double _containerHighestTint = 0.66;
  static const double _outlineVariantTint = 0.58;
  static const double _outlineTint = 0.34;

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
    final sandBase = _parseHex(surface);

    Color sand(double tint) => _shade(sandBase, tint);

    // الحبرُ يحمل مسحةً من لون المعهد لا حياداً رمادياً: نصٌّ أسودُ تماماً فوق بياضٍ
    // دافئ يبدو غريباً عنه، والمسحةُ تربط النصَّ بالصفحة بلا أن تُضعف تباينه.
    final ink = _shade(_parseHex(primary), -0.74);
    final mutedInk = _shade(_parseHex(primary), -0.40);

    final colorScheme = ColorScheme.light(
      primary: brand[600]!,
      onPrimary: Colors.white,
      primaryContainer: brand[100]!,
      onPrimaryContainer: brand[900]!,
      // الخام كما في اللوحة (gold-500 = المُدخَل حرفياً) — العقدُ واحد، ولا يُغيَّر
      // معناه هنا. وحبرُه داكنٌ منه لأن معاهد كثيرة تختار ثانوياً فاتحاً.
      secondary: gold[500]!,
      onSecondary: _shade(_parseHex(secondary), -0.62),
      secondaryContainer: gold[300]!,
      onSecondaryContainer: _shade(_parseHex(secondary), -0.62),
      surface: sand(_pageTint),
      onSurface: ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: sand(_containerLowTint),
      surfaceContainer: sand(_containerTint),
      surfaceContainerHigh: sand(_containerHighTint),
      surfaceContainerHighest: sand(_containerHighestTint),
      onSurfaceVariant: mutedInk,
      outline: sand(_outlineTint),
      outlineVariant: sand(_outlineVariantTint),
      surfaceTint: brand[600]!,
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
      // الترويسةُ وحدها تحمل لون المعهد كاملاً — وهي مرساةُ الشاشة. جُرّبت مقابلها
      // ترويسةٌ بيضاء بعنوانٍ ملوّن على جهازٍ فعلي: أهدأ، لكن الشاشةَ الكثيفة تفقد
      // حدَّها الأعلى فتذوب الحقولُ في حقلٍ واحد. فالهويةُ شريطٌ أعلى، وما تحته بياض.
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Reem Kufi',
          fontSize: 20,
          color: colorScheme.onPrimary,
        ),
      ),
      // البطاقةُ بيضاءُ ناصعة فوق صفحةٍ دافئة — الفرقُ الذي يجعلها ترتفع عنها.
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      // الحوارُ أبيضُ معتم: كان يرث لون الصفحة فيبدو شفافاً فوق ما تحته.
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          fontFamily: 'Reem Kufi',
          fontSize: 19,
          color: colorScheme.onSurface,
        ),
      ),
      // منتقي التاريخ حوارٌ أيضاً، ولا يرث dialogTheme — فيُضبط صراحةً أو خرج
      // كريمياً وحده بين حوارَين أبيضين.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        headerBackgroundColor: colorScheme.surfaceContainerLowest,
        headerForegroundColor: colorScheme.onSurface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // الحالةُ المختارة تُملأ بلون المعهد كاملاً لا بشفافيةٍ منه: أربعُ خاناتٍ
          // متجاورة تحتاج فصلاً قاطعاً يُقرأ بطرف العين أثناء التفقّد.
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.surfaceContainerLowest,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: colorScheme.primary),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        side: BorderSide(color: colorScheme.outlineVariant),
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
