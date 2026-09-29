import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/prefs.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../activities/domain/activity.dart';

part 'settings_provider.g.dart';

class AppSettings {
  const AppSettings({
    this.units = const Units(),
    this.themeMode = ThemeMode.system,
    this.locale,
    this.morningForecast = false,
    this.activities = Activity.defaults,
  });

  final Units units;
  final ThemeMode themeMode;

  /// Null follows the device language.
  final Locale? locale;

  /// Daily 7:00 forecast notification (opt-in; asks for permission).
  final bool morningForecast;

  /// Scored on Home's activities card; may be empty.
  final Set<Activity> activities;

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
    final language = prefs.getString(PrefKeys.language);
    return AppSettings(
      units: Units(
        temp: read(TempUnit.values, PrefKeys.tempUnit) ?? TempUnit.celsius,
        wind: read(WindUnit.values, PrefKeys.windUnit) ?? WindUnit.kmh,
      ),
      themeMode: read(ThemeMode.values, PrefKeys.themeMode) ?? ThemeMode.system,
      locale: language == null ? null : Locale(language),
      morningForecast: prefs.getBool(PrefKeys.morningForecast) ?? false,
      activities: switch (prefs.getStringList(PrefKeys.activities)) {
        final names? => {
          for (final n in names) ?Activity.values.asNameMap()[n],
        },
        null => Activity.defaults,
      },
    );
  }

  Future<void> setActivities(Set<Activity> activities) {
    final saved = _prefs.setStringList(PrefKeys.activities, [
      for (final a in activities) a.name,
    ]);
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

  Future<void> _save(String key, String value) {
    // shared_preferences updates its in-memory cache synchronously, so the
    // rebuild below already reads the new value.
    final saved = _prefs.setString(key, value);
    ref.invalidateSelf();
    return saved;
  }
}
