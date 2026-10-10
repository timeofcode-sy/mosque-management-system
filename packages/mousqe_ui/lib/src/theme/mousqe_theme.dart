import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// ثيمُ التطبيقات الأربعة: هويةُ نزلاً v3 كما تقدّمها [NuzulTheme] (فاتح: ضبابٌ وأخضرُ عميق، وليلي: ليلُ
/// المسجد ونحاس) مع ما لا تغطّيه الحزمةُ من أسطح Material — الحوارات والأوراق السفلية والمنتقيات والشرائح
/// والمفاتيح — لتخرج كلُّها بالحدّ والزاوية واللون نفسها.
///
/// ### الألوان ثابتة
/// ألوانُ المعهد (`institutes.settings.theme`) تبقى بياناتٍ في الخادم والـAPI لكنها **لا تصبغ الواجهة**:
/// لوحةُ v3 مضمونةُ التباين (4.5:1 للنص و3:1 للحدود والتركيز) في السمتين، وألوانٌ اعتباطية تكسر هذا الضمان.
/// وعلامةُ المعهد الخاصة (الشعار والاسم) تبقى ظاهرةً حيث كانت.
///
/// ### السمتان
/// التطبيقاتُ تمرّر [light] و[dark] مع `themeMode: ThemeMode.system`، فتتبع الليلُ تلقائياً.
class MousqeTheme {
  const MousqeTheme._();

  /// لمسٌ للهاتف واللوحي، وفأرةٌ ولوحةُ مفاتيح لسطح المكتب (ويندوز وماك ولينكس).
  static NzDensity get density => NuzulTheme.densityFor(defaultTargetPlatform);

  static ThemeData light({NzDensity? density}) =>
      _decorate(NuzulTheme.light(density: density ?? MousqeTheme.density));

  static ThemeData dark({NzDensity? density}) =>
      _decorate(NuzulTheme.dark(density: density ?? MousqeTheme.density));

  static ThemeData _decorate(ThemeData base) {
    final c = base.extension<NzPalette>()!.tokens;
    final small = BorderRadius.circular(NzRadius.sm);
    final medium = BorderRadius.circular(NzRadius.md);
    final dense = base.visualDensity == VisualDensity.compact;

    WidgetStateProperty<T> sel<T>(T on, T off) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? on : off);

    return base.copyWith(
      // السهمُ للخلف يشير إلى اليمين لأن الواجهة من اليمين إلى اليسار (قاعدة الأيقونات).
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const NzIcon(NzIcons.back),
        closeButtonIconBuilder: (context) => const NzIcon(NzIcons.close),
        drawerButtonIconBuilder: (context) => const NzIcon(NzIcons.menu),
        endDrawerButtonIconBuilder: (context) => const NzIcon(NzIcons.menu),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: medium, side: BorderSide(color: c.line)),
        titleTextStyle: NzType.title.copyWith(color: c.ink),
        contentTextStyle: NzType.body.copyWith(color: c.ink),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: medium, side: BorderSide(color: c.line)),
        headerBackgroundColor: c.surfaceRaised,
        headerForegroundColor: c.ink,
        todayBorder: BorderSide(color: c.primary),
        dayStyle: NzType.body,
        yearStyle: NzType.body,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: medium, side: BorderSide(color: c.line)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(NzRadius.md)),
          side: BorderSide(color: c.line),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: small, side: BorderSide(color: c.line)),
        textStyle: NzType.body.copyWith(color: c.ink),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: small, side: BorderSide(color: c.line)),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: NzType.body.copyWith(color: c.ink),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.bronzeSoft,
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: small),
        labelStyle: NzType.label.copyWith(color: c.ink),
        secondaryLabelStyle: NzType.label.copyWith(color: c.bronzeInk),
        checkmarkColor: c.bronzeInk,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: sel(c.primary, c.surfaceRaised),
          foregroundColor: sel(c.onPrimary, c.inkMuted),
          side: WidgetStatePropertyAll(BorderSide(color: c.line)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: small)),
          textStyle: WidgetStatePropertyAll(NzType.label),
          minimumSize: WidgetStatePropertyAll(Size(48, dense ? NzSize.controlHeightDense : NzSize.touchTarget)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: sel(c.onPrimary, c.inkMuted),
        trackColor: sel(c.primary, c.surfaceSunken),
        trackOutlineColor: sel(c.primary, c.inkMuted),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: sel(c.primary, Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: BorderSide(color: c.inkMuted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      radioTheme: RadioThemeData(fillColor: sel(c.primary, c.inkMuted)),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceSunken,
        circularTrackColor: c.surfaceSunken,
        linearMinHeight: 4,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        textColor: c.ink,
        titleTextStyle: NzType.body.copyWith(color: c.ink),
        subtitleTextStyle: NzType.caption.copyWith(color: c.inkMuted),
        shape: RoundedRectangleBorder(borderRadius: small),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: c.ink,
        collapsedIconColor: c.inkMuted,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: Size.square(dense ? NzSize.controlHeightDense : NzSize.touchTarget),
          shape: RoundedRectangleBorder(borderRadius: small),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.focus,
        selectionColor: c.bronzeSoft,
        selectionHandleColor: c.focus,
      ),
      // أشرطةُ التمرير بألوان الهوية: رفيعةٌ بمقبضٍ line (يزداد وضوحاً عند المرور) ومجرىً شفّاف.
      // في الواجهة العربية يقع شريطُ المحتوى الرئيسي عند أقصى اليسار (اتجاهُ العنصر)، وشريطُ القائمة الجانبية
      // يُجعل يميناً بـ `ScrollbarOrientation.right` عند بنائها.
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.dragged)
              ? c.inkMuted
              : c.line,
        ),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
        radius: const Radius.circular(NzRadius.sm),
        crossAxisMargin: 2,
      ),
    );
  }
}
