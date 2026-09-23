import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Groups WMO weather codes returned by Open-Meteo.
/// https://open-meteo.com/en/docs (section "WMO Weather interpretation codes")
enum WeatherCondition {
  clear,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  showers,
  snow,
  thunderstorm,
  unknown;

  static WeatherCondition fromCode(int code) => switch (code) {
    0 => clear,
    1 => mainlyClear,
    2 => partlyCloudy,
    3 => overcast,
    45 || 48 => fog,
    51 || 53 || 55 || 56 || 57 => drizzle,
    61 || 63 || 65 || 66 || 67 => rain,
    80 || 81 || 82 => showers,
    71 || 73 || 75 || 77 || 85 || 86 => snow,
    95 || 96 || 99 => thunderstorm,
    _ => unknown,
  };

  IconData icon({bool isDay = true}) => switch (this) {
    clear => isDay ? Icons.wb_sunny : Icons.nightlight_round,
    mainlyClear || partlyCloudy => isDay ? Icons.wb_cloudy : Icons.nights_stay,
    overcast => Icons.cloud,
    fog => Icons.foggy,
    drizzle || rain || showers => Icons.water_drop,
    snow => Icons.ac_unit,
    thunderstorm => Icons.thunderstorm,
    unknown => Icons.help_outline,
  };

  String label(AppLocalizations l10n) => switch (this) {
    clear => l10n.conditionClear,
    mainlyClear => l10n.conditionMainlyClear,
    partlyCloudy => l10n.conditionPartlyCloudy,
    overcast => l10n.conditionOvercast,
    fog => l10n.conditionFog,
    drizzle => l10n.conditionDrizzle,
    rain => l10n.conditionRain,
    showers => l10n.conditionShowers,
    snow => l10n.conditionSnow,
    thunderstorm => l10n.conditionThunderstorm,
    unknown => l10n.conditionUnknown,
  };
}
