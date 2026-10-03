import 'package:flutter/material.dart';

import 'tokens.dart';

/// The two Inmore themes.
///
/// Neutral ink and paper carry the interface; colour is spent only where it
/// means something — a stage, a warning, the brand stripe. Primary is ink
/// (not a hue) so buttons and focus rings read as quiet black on paper and
/// paper on night. Cyan is the secondary: selection, links, live progress.
///
/// [dense] is for the desktop, where people sit in front of it all day and
/// want more rows on screen; the phone keeps comfortable touch targets.
abstract final class InmoreTheme {
  static ThemeData light({bool dense = false}) =>
      _build(_lightScheme, InmoreTokens.light, dense);

  static ThemeData dark({bool dense = false}) =>
      _build(_darkScheme, InmoreTokens.dark, dense);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Ground.ink,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE7E7E4),
    onPrimaryContainer: Ground.ink,
    secondary: Color(0xFF0077B6),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDDF0FA),
    onSecondaryContainer: Color(0xFF004A72),
    tertiary: Color(0xFFC2006B),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFE0EF),
    onTertiaryContainer: Color(0xFF6B003A),
    error: Color(0xFFC62828),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDE8E7),
    onErrorContainer: Color(0xFF7A1212),
    surface: Ground.paper,
    onSurface: Ground.ink,
    onSurfaceVariant: Color(0xFF5E5F65),
    surfaceDim: Color(0xFFE2E2DF),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1F1EE),
    surfaceContainer: Color(0xFFECECE9),
    surfaceContainerHigh: Color(0xFFE6E6E3),
    surfaceContainerHighest: Color(0xFFE0E0DC),
    outline: Color(0xFFC4C4C0),
    outlineVariant: Color(0xFFE3E3DF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2A2A2D),
    onInverseSurface: Color(0xFFF2F2F0),
    inversePrimary: Color(0xFFF2F2F0),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF2F2F0),
    onPrimary: Ground.night,
    primaryContainer: Color(0xFF2C2D31),
    onPrimaryContainer: Color(0xFFF2F2F0),
    secondary: Color(0xFF4CC3F5),
    onSecondary: Color(0xFF00334D),
    secondaryContainer: Color(0xFF0C3A52),
    onSecondaryContainer: Color(0xFFC2E9FB),
    tertiary: Color(0xFFFF5CAD),
    onTertiary: Color(0xFF4A0027),
    tertiaryContainer: Color(0xFF5A0F37),
    onTertiaryContainer: Color(0xFFFFD6E9),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF4A0B0B),
    errorContainer: Color(0xFF4A1719),
    onErrorContainer: Color(0xFFFFDAD7),
    surface: Ground.night,
    onSurface: Color(0xFFECECEA),
    onSurfaceVariant: Color(0xFFA2A3A9),
    surfaceDim: Color(0xFF0E0F11),
    surfaceBright: Color(0xFF2E2F33),
    surfaceContainerLowest: Color(0xFF17181B),
    surfaceContainerLow: Color(0xFF1A1B1E),
    surfaceContainer: Color(0xFF1F2023),
    surfaceContainerHigh: Color(0xFF26272A),
    surfaceContainerHighest: Color(0xFF2E2F33),
    outline: Color(0xFF4A4B50),
    outlineVariant: Color(0xFF2C2D31),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFECECEA),
    onInverseSurface: Color(0xFF1D1D1B),
    inversePrimary: Ground.ink,
  );

  static ThemeData _build(ColorScheme c, InmoreTokens tokens, bool dense) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: c,
      fontFamily: 'Rubik',
      // The font ships in this package, so the apps see it as
      // `packages/inmore_ui/Rubik`. Without this the family silently falls
      // back to the platform font.
      package: 'inmore_ui',
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
    );
    final t = base.textTheme;
    final text = t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: t.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      bodySmall: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: dense ? 16 : 20,
      vertical: dense ? 12 : 14,
    );
    OutlineInputBorder border(Color colour, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colour, width: width),
        );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: c.surface,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: c.onSurface),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded,
          padding: buttonPadding,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded,
          padding: buttonPadding,
          side: BorderSide(color: c.outline),
          foregroundColor: c.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rounded,
          foregroundColor: c.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: rounded,
          foregroundColor: c.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerLowest,
        isDense: dense,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: dense ? 14 : 16,
        ),
        border: border(c.outline),
        enabledBorder: border(c.outline),
        focusedBorder: border(c.primary, 1.6),
        errorBorder: border(c.error),
        focusedErrorBorder: border(c.error, 1.6),
        disabledBorder: border(c.outlineVariant),
        hintStyle: TextStyle(color: c.onSurfaceVariant.withValues(alpha: 0.8)),
        prefixIconColor: c.onSurfaceVariant,
        suffixIconColor: c.onSurfaceVariant,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.surfaceContainerLowest,
          isDense: dense,
          border: border(c.outline),
          enabledBorder: border(c.outline),
          focusedBorder: border(c.primary, 1.6),
        ),
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md)),
          ),
          backgroundColor: WidgetStatePropertyAll(c.surfaceContainerLowest),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md)),
          ),
          backgroundColor: WidgetStatePropertyAll(c.surfaceContainerLowest),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        side: BorderSide(color: c.outline),
        backgroundColor: c.surfaceContainerLowest,
        selectedColor: c.secondaryContainer,
        checkmarkColor: c.onSecondaryContainer,
        labelStyle: text.labelLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.secondaryContainer,
          selectedForegroundColor: c.onSecondaryContainer,
          side: BorderSide(color: c.outline),
          shape: rounded,
          textStyle: text.labelMedium,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
        titleTextStyle: text.titleLarge?.copyWith(color: c.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInverseSurface),
        actionTextColor: c.brightness == Brightness.light
            ? const Color(0xFF7FD3F7)
            : const Color(0xFF0077B6),
        shape: rounded,
        insetPadding: const EdgeInsets.all(16),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: text.labelMedium?.copyWith(color: c.onInverseSurface),
        waitDuration: const Duration(milliseconds: 400),
      ),
      listTileTheme: ListTileThemeData(
        shape: rounded,
        iconColor: c.onSurfaceVariant,
        selectedColor: c.onSecondaryContainer,
        selectedTileColor: c.secondaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.secondaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected)
                ? c.onSurface
                : c.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? c.onSecondaryContainer
                : c.onSurfaceVariant,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.secondary,
        linearTrackColor: c.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.primary
              : c.surfaceContainerHighest,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(c.outline.withValues(alpha: 0.7)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.surfaceContainerLowest,
        headerForegroundColor: c.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),
    );
  }
}
