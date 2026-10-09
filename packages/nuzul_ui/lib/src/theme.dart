import 'package:flutter/material.dart';

import 'generated/tokens.dart';

/// Input style of the platform the app runs on.
enum NzDensity {
  /// Phones and tablets: 44px controls, 48px hit areas.
  touch,

  /// Windows, macOS, Linux and the web on a desktop: 36px controls, compact density.
  desktop,
}

/// The theme's colour tokens, reachable from any widget with `context.nz`.
@immutable
class NzPalette extends ThemeExtension<NzPalette> {
  const NzPalette(this.tokens);

  final NzColorTokens tokens;

  @override
  NzPalette copyWith({NzColorTokens? tokens}) => NzPalette(tokens ?? this.tokens);

  @override
  NzPalette lerp(covariant NzPalette? other, double t) => t < 0.5 || other == null ? this : other;
}

extension NzThemeContext on BuildContext {
  /// The Nuzulan colour tokens of the current theme (light or night).
  NzColorTokens get nz => Theme.of(this).extension<NzPalette>()?.tokens ?? NzColorTokens.light;
}

/// ThemeData built from the Nuzulan tokens. Material 3, right to left, the brand fonts bundled.
abstract final class NuzulTheme {
  static const _sans = 'packages/$nzPackage/${NzFonts.sans}';

  /// Light theme: mist ground, deep green actions.
  static ThemeData light({NzDensity density = NzDensity.touch}) =>
      _build(NzColorTokens.light, Brightness.light, density);

  /// Night theme: the logo's ground, bronze actions.
  static ThemeData dark({NzDensity density = NzDensity.touch}) =>
      _build(NzColorTokens.dark, Brightness.dark, density);

  /// Picks the density from the platform: desktop for Windows, macOS and Linux, touch otherwise.
  static NzDensity densityFor(TargetPlatform platform) => switch (platform) {
        TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => NzDensity.desktop,
        _ => NzDensity.touch,
      };

  static ThemeData _build(NzColorTokens c, Brightness b, NzDensity density) {
    final dense = density == NzDensity.desktop;
    final controlHeight = dense ? NzSize.controlHeightDense : NzSize.controlHeight;
    final onDark = b == Brightness.dark;
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.bronzeSoft,
      onPrimaryContainer: c.bronzeInk,
      secondary: c.bronzeInk,
      onSecondary: onDark ? NzBrand.night : const Color(0xFFFFFFFF),
      secondaryContainer: c.bronzeSoft,
      onSecondaryContainer: c.bronzeInk,
      tertiary: c.progressCurrent,
      onTertiary: onDark ? NzBrand.night : const Color(0xFFFFFFFF),
      error: c.danger,
      onError: onDark ? NzBrand.night : const Color(0xFFFFFFFF),
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerLowest: c.surfaceRaised,
      surfaceContainerLow: c.surfaceRaised,
      surfaceContainer: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceSunken,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.inkMuted,
      outlineVariant: c.line,
      inverseSurface: c.ink,
      onInverseSurface: c.surface,
      inversePrimary: onDark ? NzColorTokens.light.primary : NzColorTokens.dark.primary,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      surfaceTint: const Color(0x00000000),
    );
    final text = TextTheme(
      displayLarge: NzType.display1,
      displayMedium: NzType.display2,
      displaySmall: NzType.display3,
      headlineMedium: NzType.display3,
      titleLarge: NzType.title,
      titleMedium: NzType.title.copyWith(fontSize: 17, height: 26 / 17),
      titleSmall: NzType.label.copyWith(fontSize: 15, height: 24 / 15, fontWeight: FontWeight.w600),
      bodyLarge: NzType.bodyLg,
      bodyMedium: NzType.body,
      bodySmall: NzType.caption,
      labelLarge: NzType.label.copyWith(fontSize: 15, height: 1.2),
      labelMedium: NzType.label,
      labelSmall: NzType.caption.copyWith(fontWeight: FontWeight.w500, fontSize: 11, height: 16 / 11),
    ).apply(bodyColor: c.ink, displayColor: c.ink);
    final small = BorderRadius.circular(NzRadius.sm);
    final medium = BorderRadius.circular(NzRadius.md);
    WidgetStateProperty<T> sel<T>(T on, T off) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? on : off);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _sans,
      textTheme: text,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      dividerColor: c.line,
      focusColor: c.focus.withValues(alpha: 0.24),
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.ink, size: 24),
      extensions: [NzPalette(c)],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surfaceRaised,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: NzSize.appbarHeight,
        titleTextStyle: NzType.display3.copyWith(fontSize: 22, height: 32 / 22, color: c.ink),
        shape: Border(bottom: BorderSide(color: c.line)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: Size(64, controlHeight),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s5),
          shape: RoundedRectangleBorder(borderRadius: small),
          textStyle: NzType.label.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.surfaceRaised,
          side: BorderSide(color: c.line),
          minimumSize: Size(64, controlHeight),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s5),
          shape: RoundedRectangleBorder(borderRadius: small),
          textStyle: NzType.label.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: Size(48, controlHeight),
          shape: RoundedRectangleBorder(borderRadius: small),
          textStyle: NzType.label.copyWith(fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        isDense: dense,
        contentPadding: EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s3, vertical: dense ? 8 : 12),
        labelStyle: NzType.label.copyWith(color: c.ink),
        floatingLabelStyle: NzType.label.copyWith(color: c.ink),
        hintStyle: NzType.body.copyWith(color: c.inkMuted),
        helperStyle: NzType.caption.copyWith(color: c.inkMuted),
        errorStyle: NzType.caption.copyWith(color: c.danger),
        border: OutlineInputBorder(borderRadius: small, borderSide: BorderSide(color: c.line)),
        enabledBorder: OutlineInputBorder(borderRadius: small, borderSide: BorderSide(color: c.line)),
        focusedBorder: OutlineInputBorder(borderRadius: small, borderSide: BorderSide(color: c.focus, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: small, borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: small, borderSide: BorderSide(color: c.danger, width: 2)),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: medium, side: BorderSide(color: c.line)),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceRaised,
        indicatorColor: c.bronzeSoft,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        height: 72,
        labelTextStyle: sel(
          NzType.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: c.bronzeInk),
          NzType.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: c.inkMuted),
        ),
        iconTheme: sel(IconThemeData(color: c.bronzeInk, size: 22), IconThemeData(color: c.inkMuted, size: 22)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surfaceRaised,
        indicatorColor: c.bronzeSoft,
        minWidth: NzSize.railWidth,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(color: c.bronzeInk, size: 22),
        unselectedIconTheme: IconThemeData(color: c.inkMuted, size: 22),
        selectedLabelTextStyle: NzType.caption.copyWith(fontWeight: FontWeight.w600, color: c.bronzeInk),
        unselectedLabelTextStyle: NzType.caption.copyWith(color: c.inkMuted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.ink,
        unselectedLabelColor: c.inkMuted,
        indicatorColor: c.primary,
        dividerColor: c.line,
        labelStyle: NzType.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: NzType.label.copyWith(fontSize: 14),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(c.surfaceSunken),
        headingTextStyle: NzType.caption.copyWith(fontWeight: FontWeight.w600, color: c.inkMuted),
        dataTextStyle: NzType.body.copyWith(fontSize: 14, color: c.ink),
        dividerThickness: 1,
        headingRowHeight: 40,
        dataRowMinHeight: dense ? 44 : 52,
        dataRowMaxHeight: dense ? 52 : 64,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: NzType.body.copyWith(color: c.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: small),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: NzType.caption.copyWith(color: c.surface),
        decoration: BoxDecoration(color: c.ink, borderRadius: small),
      ),
    );
  }
}
