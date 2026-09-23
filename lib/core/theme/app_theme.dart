import 'package:flutter/material.dart';

/// App-specific colors not covered by [ColorScheme].
/// Read via `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textMuted,
    required this.card,
    required this.sunny,
    required this.rainy,
  });

  final Color textMuted;
  final Color card;
  final Color sunny;
  final Color rainy;

  static const light = AppColors(
    textMuted: Color(0xFF64748B),
    card: Color(0xFFF1F5F9),
    sunny: Color(0xFFF59E0B),
    rainy: Color(0xFF3B82F6),
  );

  static const dark = AppColors(
    textMuted: Color(0xFF94A3B8),
    card: Color(0xFF1E293B),
    sunny: Color(0xFFFBBF24),
    rainy: Color(0xFF60A5FA),
  );

  @override
  AppColors copyWith({
    Color? textMuted,
    Color? card,
    Color? sunny,
    Color? rainy,
  }) => AppColors(
    textMuted: textMuted ?? this.textMuted,
    card: card ?? this.card,
    sunny: sunny ?? this.sunny,
    rainy: rainy ?? this.rainy,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      card: Color.lerp(card, other.card, t)!,
      sunny: Color.lerp(sunny, other.sunny, t)!,
      rainy: Color.lerp(rainy, other.rainy, t)!,
    );
  }
}

abstract final class AppTheme {
  static const _seed = Color(0xFF3B82F6);

  static final light = _build(Brightness.light, AppColors.light);
  static final dark = _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    extensions: [colors],
  );
}
