import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/prefs.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../activities/domain/activity.dart';
import '../../../alerts/data/alerts_sync_ds.dart';
import '../../../weather/domain/entities/weather.dart';

part 'settings_provider.g.dart';

class AppSettings {
  const AppSettings({
    this.units = const Units(),
    this.themeMode = ThemeMode.system,
    this.locale,
    this.morningForecast = false,
    this.activities = Activity.defaults,
    this.weatherAlerts = false,
    this.alertTypes = const {...AlertType.values},
    this.health = const {},
  });

  final Units units;
  final ThemeMode themeMode;

  /// Null follows the device language.
  final Locale? locale;

  /// Daily 7:00 forecast notification (opt-in; asks for permission).
  final bool morningForecast;

  /// Scored on Home's activities card; may be empty.
  final Set<Activity> activities;

  /// Server-sent push alerts (opt-in; asks for permission). Only offered in
  /// builds with Firebase keys.
  final bool weatherAlerts;
  final Set<AlertType> alertTypes;

  /// Tightens tips, activity scores and push alerts; empty for a healthy
  /// adult.
  final Set<HealthProfile> health;

  Limits get limits => Limits.of(health);

  /// Language for API calls (place and city names).
  Locale get effectiveLocale => locale ?? PlatformDispatcher.instance.locale;
}

/// Each setter writes shared_preferences and rebuilds from it, so prefs stay
/// the single source of truth.
@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T? read<T extends Enum>(List<T> values, String key) =>
        values.asNameMap()[prefs.getString(key)];
    // Unknown names (from a removed option) are dropped; never stored means
    // the default, while a stored empty list stays empty.
    Set<T> readSet<T extends Enum>(List<T> values, String key, Set<T> or) =>
        switch (prefs.getStringList(key)) {
          final names? => {for (final n in names) ?values.asNameMap()[n]},
          null => or,
        };
    final language = prefs.getString(PrefKeys.language);
    return AppSettings(
      units: Units(
        temp: read(TempUnit.values, PrefKeys.tempUnit) ?? TempUnit.celsius,
        wind: read(WindUnit.values, PrefKeys.windUnit) ?? WindUnit.kmh,
      ),
      themeMode: read(ThemeMode.values, PrefKeys.themeMode) ?? ThemeMode.system,
      locale: language == null ? null : Locale(language),
      morningForecast: prefs.getBool(PrefKeys.morningForecast) ?? false,
      activities: readSet(
        Activity.values,
        PrefKeys.activities,
        Activity.defaults,
      ),
      weatherAlerts: prefs.getBool(PrefKeys.weatherAlerts) ?? false,
      alertTypes: readSet(AlertType.values, PrefKeys.alertTypes, {
        ...AlertType.values,
      }),
      health: readSet(HealthProfile.values, PrefKeys.health, {}),
    );
  }

  Future<void> setActivities(Set<Activity> activities) =>
      _saveSet(PrefKeys.activities, activities);

  Future<void> setAlertTypes(Set<AlertType> types) =>
      _saveSet(PrefKeys.alertTypes, types);

  Future<void> setHealth(Set<HealthProfile> health) =>
      _saveSet(PrefKeys.health, health);

  Future<void> setWeatherAlerts(bool on) {
    final saved = _prefs.setBool(PrefKeys.weatherAlerts, on);
    ref.invalidateSelf();
    return saved;
  }

  Future<void> setTempUnit(TempUnit unit) =>
      _save(PrefKeys.tempUnit, unit.name);

  Future<void> setWindUnit(WindUnit unit) =>
      _save(PrefKeys.windUnit, unit.name);

  Future<void> setThemeMode(ThemeMode mode) =>
      _save(PrefKeys.themeMode, mode.name);

  Future<void> setLanguage(String languageCode) =>
      _save(PrefKeys.language, languageCode);

  Future<void> setMorningForecast(bool on) {
    final saved = _prefs.setBool(PrefKeys.morningForecast, on);
    ref.invalidateSelf();
    return saved;
  }

  Future<void> _saveSet(String key, Set<Enum> values) {
    final saved = _prefs.setStringList(key, [for (final v in values) v.name]);
    ref.invalidateSelf();
    return saved;
  }

  Future<void> _save(String key, String value) {
    // shared_preferences updates its in-memory cache synchronously, so the
    // rebuild below already reads the new value.
    final saved = _prefs.setString(key, value);
    ref.invalidateSelf();
    return saved;
  }
}
