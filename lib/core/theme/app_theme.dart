import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../utils/weather_code_mapper.dart';

/// App-specific colors not covered by [ColorScheme].
/// Read via `context.colors`. Values mirror design/…/Skycast Foundations.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textMuted,
    required this.card,
    required this.sunny,
    required this.rainy,
    required this.onWeather,
    required this.glass,
  });

  final Color textMuted;
  final Color card;
  final Color sunny;
  final Color rainy;

  /// Text and icons on weather gradients; same in both themes.
  final Color onWeather;

  /// Translucent card fill on weather gradients; same in both themes.
  final Color glass;

  static const light = AppColors(
    // Design's #64748B fails AA on card (4.3:1); its contrast audit
    // recommends #475569.
    textMuted: Color(0xFF475569),
    card: Color(0xFFF1F5F9),
    sunny: Color(0xFFF59E0B),
    rainy: Color(0xFF3B82F6),
    onWeather: Color(0xFFFFFFFF),
    glass: Color(0x29FFFFFF),
  );

  static const dark = AppColors(
    textMuted: Color(0xFF94A3B8),
    card: Color(0xFF1E293B),
    sunny: Color(0xFFFBBF24),
    rainy: Color(0xFF60A5FA),
    onWeather: Color(0xFFFFFFFF),
    glass: Color(0x29FFFFFF),
  );

  @override
  AppColors copyWith({
    Color? textMuted,
    Color? card,
    Color? sunny,
    Color? rainy,
    Color? onWeather,
    Color? glass,
  }) => AppColors(
    textMuted: textMuted ?? this.textMuted,
    card: card ?? this.card,
    sunny: sunny ?? this.sunny,
    rainy: rainy ?? this.rainy,
    onWeather: onWeather ?? this.onWeather,
    glass: glass ?? this.glass,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      card: Color.lerp(card, other.card, t)!,
      sunny: Color.lerp(sunny, other.sunny, t)!,
      rainy: Color.lerp(rainy, other.rainy, t)!,
      onWeather: Color.lerp(onWeather, other.onWeather, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
    );
  }
}

/// Home background. Identical in both app themes, so it isn't a
/// [ThemeExtension].
LinearGradient weatherGradient(
  WeatherCondition condition, {
  required bool isDay,
}) {
  final (day, night) = switch (condition) {
    WeatherCondition.clear || WeatherCondition.mainlyClear => (
      (0xFF2272D6, 0xFF0F4DA8),
      (0xFF1E2A5E, 0xFF0B1026),
    ),
    WeatherCondition.fog => (
      (0xFF6B7784, 0xFF4A5561),
      (0xFF343C4C, 0xFF181C25),
    ),
    WeatherCondition.drizzle ||
    WeatherCondition.rain ||
    WeatherCondition.showers => (
      (0xFF3A6A94, 0xFF1D3F63),
      (0xFF1B3350, 0xFF0A1424),
    ),
    WeatherCondition.snow => (
      (0xFF4A78A6, 0xFF2A5584),
      (0xFF2A3766, 0xFF10162E),
    ),
    WeatherCondition.thunderstorm => (
      (0xFF4A4468, 0xFF24223A),
      (0xFF231B3D, 0xFF09081A),
    ),
    WeatherCondition.partlyCloudy ||
    WeatherCondition.overcast ||
    WeatherCondition.unknown => (
      (0xFF5A7390, 0xFF3A4F66),
      (0xFF2E3A52, 0xFF151B28),
    ),
  };
  final (top, bottom) = isDay ? day : night;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(top), Color(bottom)],
  );
}

abstract final class AppTheme {
  static const _fontFamily = 'BeVietnamPro';

  static final light = _build(
    ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)).copyWith(
      primary: const Color(0xFF2563EB),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFDBEAFE),
      onPrimaryContainer: const Color(0xFF1E3A8A),
      surface: const Color(0xFFF8FAFC),
      onSurface: const Color(0xFF0F172A),
      surfaceContainer: const Color(0xFFFFFFFF),
      outline: const Color(0xFFE2E8F0),
      error: const Color(0xFFDC2626),
      onError: const Color(0xFFFFFFFF),
    ),
    AppColors.light,
  );

  static final dark = _build(
    ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF60A5FA),
      onPrimary: const Color(0xFF0B1220),
      primaryContainer: const Color(0xFF1E3A8A),
      onPrimaryContainer: const Color(0xFFDBEAFE),
      surface: const Color(0xFF0F172A),
      onSurface: const Color(0xFFF1F5F9),
      surfaceContainer: const Color(0xFF1E293B),
      outline: const Color(0xFF334155),
      error: const Color(0xFFF87171),
      onError: const Color(0xFF0B1220),
    ),
    AppColors.dark,
  );

  /// Shimmer from `card` to `outline`, as in the Components page.
  static final skeleton = SkeletonizerConfigData(
    effectResolver: (brightness) {
      final isLight = brightness == Brightness.light;
      return ShimmerEffect(
        baseColor: (isLight ? AppColors.light : AppColors.dark).card,
        highlightColor: (isLight ? light : dark).colorScheme.outline,
        duration: const Duration(milliseconds: 1600),
      );
    },
  );

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(double size, double line, FontWeight weight) =>
      TextStyle(
        fontSize: size,
        height: line / size,
        fontWeight: weight,
        fontFeatures: _tabular,
      );

  static final _textTheme = TextTheme(
    displayLarge: _style(96, 100, FontWeight.w200).copyWith(letterSpacing: -2),
    headlineMedium: _style(28, 36, FontWeight.w600),
    titleLarge: _style(22, 28, FontWeight.w600),
    titleMedium: _style(16, 24, FontWeight.w600),
    bodyLarge: _style(16, 24, FontWeight.w400),
    bodyMedium: _style(14, 20, FontWeight.w400),
    labelLarge: _style(14, 20, FontWeight.w600),
    labelMedium: _style(12, 16, FontWeight.w500),
  );

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    const buttonShape = StadiumBorder();
    const buttonSize = Size(64, 48);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24);
    final isLight = scheme.brightness == Brightness.light;
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: _fontFamily,
      textTheme: _textTheme,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme.titleLarge!.copyWith(
          fontFamily: _fontFamily,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: _textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: _textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        hintStyle: TextStyle(color: colors.textMuted),
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainer,
        contentTextStyle: _textTheme.bodyMedium!.copyWith(
          fontFamily: _fontFamily,
          color: scheme.onSurface,
        ),
        actionTextColor: scheme.primary,
        elevation: isLight ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
    );
  }
}
