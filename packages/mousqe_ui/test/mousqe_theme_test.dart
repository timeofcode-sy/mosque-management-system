import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/src/theme/mousqe_theme.dart';

/// أمثلة مطابقة لخوارزمية `InstituteTheme::shade()` على الألوان الافتراضية في
/// `InstituteTheme::DEFAULTS` — الدرجة الأساسية (ratio 0.0) تساوي اللون
/// المُدخَل حرفياً، وبقية الدرجات نتاج نفس الخلط الخطّي لا نسخة عن
/// design-tokens.json (تلك لوحة مُعايَرة يدوياً، وهذا اشتقاقٌ حسابي).
void main() {
  test('the default colors produce the design-tokens brand-600 shade unchanged', () {
    final shades = MousqeTheme.shades(MousqeTheme.defaultPrimary, {600: 0.0});

    expect(shades[600], const Color(0xFF0F5132));
  });

  test('shade() blends toward white for a positive ratio and black for a negative one', () {
    // نفس صيغة InstituteTheme::shade() الخادمية: mix = channel + (target-channel)*ratio.
    final shades = MousqeTheme.shades(MousqeTheme.defaultPrimary, {50: 0.92, 900: -0.50});

    expect(shades[50], const Color(0xFFECF1EF));
    expect(shades[900], const Color(0xFF082919));
  });

  test('fallback() builds a theme matching design-tokens.json with no institute colors', () {
    final theme = MousqeTheme.fallback();

    expect(theme.colorScheme.primary, const Color(0xFF0F5132));
    expect(theme.colorScheme.secondary, const Color(0xFFC9A227));
    expect(theme.colorScheme.surface, const Color(0xFFF7F3EA));
  });

  test('fromColors builds a consistent theme from arbitrary colors with no exception', () {
    final theme = MousqeTheme.fromColors(
      primary: '#7d0a0a',
      secondary: '#ffbf9b',
      surface: '#ead196',
    );

    expect(theme.colorScheme.primary, const Color(0xFF7D0A0A));
    expect(theme.colorScheme.secondary, const Color(0xFFFFBF9B));
    expect(theme.colorScheme.surface, const Color(0xFFEAD196));
  });

  test('shades() returns a scale of the correct length for arbitrary ratios', () {
    final shades = MousqeTheme.shades('#123456', {
      300: 0.5,
      400: 0.2,
      500: 0.0,
      600: -0.2,
      700: -0.4,
    });

    expect(shades, hasLength(5));
    expect(shades.keys, containsAll([300, 400, 500, 600, 700]));
  });
}
