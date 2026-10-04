import 'package:flutter/material.dart';

/// Parfum IM brand tokens.
///
/// These are the raw palette values: they do not change with the brightness, so
/// they must only be used where a fixed brand colour is intended (logo, gold
/// fills on buttons). Anything that carries *meaning* — text, surfaces, status
/// colours — has to be read from [AppPalette] so it stays readable in both light
/// and dark mode.
class AppColors {
  const AppColors._();

  /// Brand gold. Unreadable as text on a white surface.
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldSoft = Color(0xFFB8932B);

  /// Dark-mode accents, kept for icons on media overlays.
  static const Color charcoal = Color(0xFF121212);

  static const Color danger = Color(0xFFE05252);
  static const Color success = Color(0xFF4CAF7D);
  static const Color warning = Color(0xFFE0A32E);
  static const Color info = Color(0xFF4A90D9);
}

/// Semantic colours that follow the active brightness.
///
/// Accessed with `context.palette`, so widgets never hard-code a colour that
/// only works on one background.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.scaffold,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.goldText,
    required this.onGold,
    required this.danger,
    required this.success,
    required this.warning,
    required this.info,
    required this.shadow,
  });

  final Brightness brightness;

  /// Page background behind cards.
  final Color scaffold;

  /// Card / sheet background.
  final Color surface;

  /// Inputs, chips and image placeholders.
  final Color surfaceAlt;

  /// Recessed areas (empty states, chart backgrounds).
  final Color surfaceSunken;

  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Gold tuned for text/icons on [scaffold]; darker than [AppColors.gold] in
  /// light mode so it clears the WCAG contrast bar.
  final Color goldText;

  /// Foreground used on top of a gold fill.
  final Color onGold;

  final Color danger;
  final Color success;
  final Color warning;
  final Color info;

  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    scaffold: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceAlt: Color(0xFF272727),
    surfaceSunken: Color(0xFF161616),
    border: Color(0xFF323232),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB0B0B0),
    textMuted: Color(0xFF8A8A8A),
    goldText: AppColors.gold,
    onGold: Color(0xFF1A1405),
    danger: AppColors.danger,
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    shadow: Color(0x66000000),
  );

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    scaffold: Color(0xFFF6F3ED),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0ECE3),
    surfaceSunken: Color(0xFFEDE8DE),
    border: Color(0xFFE0DACD),
    textPrimary: Color(0xFF1B1B1B),
    textSecondary: Color(0xFF575757),
    textMuted: Color(0xFF7A7A7A),
    goldText: Color(0xFF8A6A12),
    onGold: Color(0xFFFFFFFF),
    danger: Color(0xFFC0392B),
    success: Color(0xFF1E7A4D),
    warning: Color(0xFFA9670A),
    info: Color(0xFF2C6BB0),
    shadow: Color(0x1A000000),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? scaffold,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? goldText,
    Color? onGold,
    Color? danger,
    Color? success,
    Color? warning,
    Color? info,
    Color? shadow,
  }) => AppPalette(
    brightness: brightness ?? this.brightness,
    scaffold: scaffold ?? this.scaffold,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    surfaceSunken: surfaceSunken ?? this.surfaceSunken,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    goldText: goldText ?? this.goldText,
    onGold: onGold ?? this.onGold,
    danger: danger ?? this.danger,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    shadow: shadow ?? this.shadow,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Shortcut so widgets can write `context.palette.textPrimary`.
extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      AppPalette.of(Theme.of(this).brightness);
}

/// Parfum IM visual language: a warm charcoal/gold dark theme and a light
/// counterpart that keeps the same gold accent with readable text contrast.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final palette = AppPalette.of(brightness);
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.gold,
          onPrimary: palette.onGold,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          error: palette.danger,
          onError: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.scaffold,
      canvasColor: palette.scaffold,
      dividerColor: palette.border,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: palette.goldText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.gold.withValues(alpha: isDark ? 0.22 : 0.30),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.goldText : palette.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? palette.goldText : palette.textSecondary,
          );
        }),
      ),
      iconTheme: IconThemeData(color: palette.textSecondary),
      listTileTheme: ListTileThemeData(
        iconColor: palette.goldText,
        textColor: palette.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.danger, width: 1.4),
        ),
        labelStyle: TextStyle(color: palette.textSecondary),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 13),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.border),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: palette.onGold,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.goldText,
          side: BorderSide(color: palette.border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.goldText),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: palette.onGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceAlt,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: palette.onGold, fontSize: 12),
        selectedColor: AppColors.gold,
        checkmarkColor: palette.onGold,
        iconTheme: IconThemeData(color: palette.textSecondary, size: 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.surfaceAlt : const Color(0xFF2C2C2C),
        contentTextStyle: TextStyle(
          color: isDark ? palette.textPrimary : Colors.white,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : palette.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold.withValues(alpha: 0.35)
              : palette.surfaceAlt,
        ),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: palette.textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: palette.textPrimary, fontSize: 13),
        bodySmall: TextStyle(color: palette.textSecondary, fontSize: 12),
        labelSmall: TextStyle(color: palette.textMuted, fontSize: 11),
      ),
    );
  }
}
