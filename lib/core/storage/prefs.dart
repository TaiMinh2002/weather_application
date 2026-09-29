import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs.g.dart';

abstract final class PrefKeys {
  static const onboarded = 'onboarded';
  static const savedCities = 'saved_cities';
  static const tempUnit = 'temp_unit';
  static const windUnit = 'wind_unit';
  static const themeMode = 'theme_mode';
  static const language = 'language';
  static const morningForecast = 'morning_forecast';
  static const activities = 'activities';
  static const weatherAlerts = 'weather_alerts';
  static const alertTypes = 'alert_types';
}

/// Loaded once in `main()` and injected via `overrideWithValue`.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('Override sharedPreferencesProvider in main()');
