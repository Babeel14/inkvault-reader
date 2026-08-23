import 'package:flutter/material.dart';

class InkTheme {
  InkTheme._();

  static const Color background = Color(0xFF101014);
  static const Color surface = Color(0xFF17171D);
  static const Color surfaceHigh = Color(0xFF1F1F27);
  static const Color outline = Color(0xFF2A2A33);
  static const Color ink = Color(0xFFE8E4DC);
  static const Color inkDim = Color(0xFF9A96A0);
  static const Color accent = Color(0xFFD9A45B);
  static const Color accentDeep = Color(0xFFB07F35);
  static const Color danger = Color(0xFFCF6679);

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF241A08),
      secondary: accentDeep,
      onSecondary: Color(0xFFF5EBDC),
      surface: surface,
      onSurface: ink,
      error: danger,
      onError: Color(0xFF2B0D12),
      outline: outline,
      surfaceContainerHighest: surfaceHigh,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const ['Roboto'],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: ink, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: surfaceHigh,
        foregroundColor: ink,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent.withValues(alpha: 0.85),
        inactiveTrackColor: outline,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(color: inkDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
    );
  }
}
