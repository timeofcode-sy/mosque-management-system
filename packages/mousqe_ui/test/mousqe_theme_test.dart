import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/src/theme/mousqe_theme.dart';

/// أمثلة مطابقة لخوارزمية `InstituteTheme::shade()` على الألوان الافتراضية في
/// `InstituteTheme::DEFAULTS` — الدرجة الأساسية (ratio 0.0) تساوي اللون
/// المُدخَل حرفياً، وبقية الدرجات نتاج نفس الخلط الخطّي لا نسخة عن
/// design-tokens.json (تلك لوحة مُعايَرة يدوياً، وهذا اشتقاقٌ حسابي).
void main() {
  test(
    'the default colors produce the design-tokens brand-600 shade unchanged',
    () {
      final shades = MousqeTheme.shades(MousqeTheme.defaultPrimary, {600: 0.0});

      expect(shades[600], const Color(0xFF0F5132));
    },
  );

  test('shade() blends toward white for a positive ratio and black for a negative one', () {
    // نفس صيغة InstituteTheme::shade() الخادمية: mix = channel + (target-channel)*ratio.
    final shades = MousqeTheme.shades(MousqeTheme.defaultPrimary, {
      50: 0.92,
      900: -0.50,
    });

    expect(shades[50], const Color(0xFFECF1EF));
    expect(shades[900], const Color(0xFF082919));
  });

  test(
    'fallback() keeps the two identity colors of design-tokens.json unchanged',
    () {
      final theme = MousqeTheme.fallback();

      expect(theme.colorScheme.primary, const Color(0xFF0F5132));
      expect(theme.colorScheme.secondary, const Color(0xFFC9A227));
    },
  );

  test('fromColors keeps primary and secondary raw — they are the institute identity', () {
    final theme = MousqeTheme.fromColors(
      primary: '#7d0a0a',
      secondary: '#ffbf9b',
      surface: '#ead196',
    );

    expect(theme.colorScheme.primary, const Color(0xFF7D0A0A));
    expect(theme.colorScheme.secondary, const Color(0xFFFFBF9B));
  });

  /// 🔄 م.5.3: كان `surface` يُسنَد خاماً فتُصبَغ الصفحةُ كلُّها بلون المعهد الثالث.
  /// صار مصدرَ حرارةٍ لا طلاءَ صفحة، والاختبارُ يثبّت الحدَّ الذي يجعله كذلك: صفحةٌ
  /// قريبةٌ من الأبيض مهما أشبع المعهدُ لونَه، وبطاقةٌ بيضاءُ ناصعة تعلوها.
  test('the page background stays near-white even for a saturated institute surface', () {
    final theme = MousqeTheme.fromColors(
      primary: '#7d0a0a',
      secondary: '#ffbf9b',
      surface: '#ead196', // رملٌ مشبع — كان يخرج خردلاً على كامل الشاشة
    );

    final surface = theme.colorScheme.surface;

    expect(surface, isNot(const Color(0xFFEAD196)));
    // كلُّ قناة فوق 240: بياضٌ دافئ لا لونٌ قائم بذاته.
    expect((surface.r * 255).round(), greaterThan(240));
    expect((surface.g * 255).round(), greaterThan(240));
    expect((surface.b * 255).round(), greaterThan(240));

    expect(theme.colorScheme.surfaceContainerLowest, const Color(0xFFFFFFFF));
    expect(theme.scaffoldBackgroundColor, surface);
  });

  test(
    'the surface scale keeps the institute hue so the identity is still felt',
    () {
      final theme = MousqeTheme.fromColors(
        primary: '#7d0a0a',
        secondary: '#ffbf9b',
        surface: '#ead196',
      );

      final surface = theme.colorScheme.surface;

      // اللونُ المُدخَل أحمرُه أعلى من أزرقه، والبياضُ المشتقُّ منه يحفظ هذا الترتيب —
      // ولولاه لصار رمادياً محايداً لا هويةَ فيه.
      expect((surface.r * 255).round(), greaterThan((surface.b * 255).round()));

      // والطبقاتُ تتدرّج: الصفحةُ أفتحُ من الحاوية، والحدُّ أدكنُ منهما.
      final scheme = theme.colorScheme;
      expect(
        (scheme.surface.r * 255).round(),
        greaterThan((scheme.surfaceContainer.r * 255).round()),
      );
      expect(
        (scheme.surfaceContainer.b * 255).round(),
        greaterThan((scheme.outlineVariant.b * 255).round()),
      );
    },
  );

  test('dialogs and cards are opaque white, never the page color', () {
    final theme = MousqeTheme.fromColors(
      primary: '#7d0a0a',
      secondary: '#ffbf9b',
      surface: '#ead196',
    );

    // الحوارُ كان يرث لون الصفحة فيبدو شفافاً فوق ما تحته.
    expect(theme.dialogTheme.backgroundColor, const Color(0xFFFFFFFF));
    expect(theme.cardTheme.color, const Color(0xFFFFFFFF));
    expect(theme.dialogTheme.backgroundColor, isNot(theme.colorScheme.surface));
  });

  test(
    'shades() returns a scale of the correct length for arbitrary ratios',
    () {
      final shades = MousqeTheme.shades('#123456', {
        300: 0.5,
        400: 0.2,
        500: 0.0,
        600: -0.2,
        700: -0.4,
      });

      expect(shades, hasLength(5));
      expect(shades.keys, containsAll([300, 400, 500, 600, 700]));
    },
  );
}
