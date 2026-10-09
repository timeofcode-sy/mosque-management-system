import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

/// الثيمُ هويةُ v3 ثابتة: فاتحٌ بضبابٍ وأخضرَ عميق، وليليٌّ بليل المسجد ونحاسه. ألوانُ المعهد لا تصبغه.
void main() {
  test('light: mist ground, deep green primary, white raised surfaces', () {
    final theme = MousqeTheme.light();

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF134236));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF3F5F2));
    expect(theme.colorScheme.surfaceContainerLow, const Color(0xFFFFFFFF));
  });

  test('dark: night ground and a bronze primary', () {
    final theme = MousqeTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xFFD6BC9C));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0A241F));
  });

  test('touch controls are 44px and desktop controls 36px', () {
    final touch = MousqeTheme.light(density: NzDensity.touch);
    final desktop = MousqeTheme.light(density: NzDensity.desktop);

    expect(
      touch.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
      NzSize.controlHeight,
    );
    expect(
      desktop.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
      NzSize.controlHeightDense,
    );
  });

  test('corners stay angular: 3px controls and 6px cards and dialogs', () {
    final theme = MousqeTheme.light();

    final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
    expect(dialog.borderRadius, BorderRadius.circular(NzRadius.md));

    final card = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(card.borderRadius, BorderRadius.circular(NzRadius.md));

    final button = theme.filledButtonTheme.style!.shape!.resolve({})!
        as RoundedRectangleBorder;
    expect(button.borderRadius, BorderRadius.circular(NzRadius.sm));
  });

  test('the brand fonts come from nuzul_ui, not from the apps', () {
    final theme = MousqeTheme.light();

    expect(theme.textTheme.bodyMedium!.fontFamily, contains('IBMPlexSansArabic'));
  });

  test('digits stay Latin', () {
    expect(nzDigits(30), '30');
  });
}
