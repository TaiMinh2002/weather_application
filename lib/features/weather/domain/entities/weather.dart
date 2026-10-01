import '../../../../core/utils/weather_code_mapper.dart';

/// Units are Open-Meteo defaults: °C, km/h, hPa, metres. Convert in the UI.
/// Times are local to the forecast location (timezone=auto).
class Weather {
  const Weather({
    required this.current,
    required this.hourly,
    required this.daily,
    this.yesterday,
    this.nowcast = const [],
    this.cachedAt,
  });

  final CurrentWeather current;

  /// All hours from today's midnight to the end of the range (7 days); see
  /// [next24Hours].
  final List<HourlyForecast> hourly;

  /// Starts today.
  final List<DailyForecast> daily;
  final DailyForecast? yesterday;

  /// Precipitation for the next 2 hours in 15-minute slots, from the current
  /// slot; see [rainOutlook].
  final List<({DateTime time, double mm})> nowcast;

  /// Set when the network failed and this came from the offline cache.
  final DateTime? cachedAt;

  List<HourlyForecast> get next24Hours {
    final from = DateTime(
      current.time.year,
      current.time.month,
      current.time.day,
      current.time.hour,
    );
    return hourly.where((h) => !h.time.isBefore(from)).take(24).toList();
  }

  /// The hours (local to the location) that fall on [day]'s date.
  List<HourlyForecast> hoursOn(DateTime day) => [
    for (final h in hourly)
      if (h.time.year == day.year &&
          h.time.month == day.month &&
          h.time.day == day.day)
        h,
  ];
}

class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.dewPoint,
    required this.isDay,
    required this.condition,
    required this.windSpeed,
    required this.windDirection,
    required this.pressure,
    required this.uvIndex,
    required this.visibility,
  });

  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double dewPoint;
  final bool isDay;
  final WeatherCondition condition;
  final double windSpeed;
  final int windDirection;
  final double pressure;
  final double uvIndex;
  final double visibility;

  UvLevel get uvLevel => UvLevel.fromIndex(uvIndex);
  CompassPoint get windFrom => CompassPoint.fromDegrees(windDirection);
}

/// WHO UV index bands.
enum UvLevel {
  low,
  moderate,
  high,
  veryHigh,
  extreme;

  static UvLevel fromIndex(double uv) => switch (uv.round()) {
    <= 2 => low,
    <= 5 => moderate,
    <= 7 => high,
    <= 10 => veryHigh,
    _ => extreme,
  };
}

/// Open-Meteo wind direction is where the wind blows from, in degrees.
enum CompassPoint {
  n,
  ne,
  e,
  se,
  s,
  sw,
  w,
  nw;

  static CompassPoint fromDegrees(int degrees) =>
      values[((degrees % 360) / 45).round() % 8];
}

class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.condition,
    required this.precipitationProbability,
    required this.isDay,
    required this.apparentTemperature,
    required this.precipitation,
    required this.windSpeed,
    required this.uvIndex,
    required this.humidity,
  });

  final DateTime time;
  final double temperature;
  final WeatherCondition condition;
  final int precipitationProbability;
  final bool isDay;
  final double apparentTemperature;

  /// mm over the hour.
  final double precipitation;
  final double windSpeed;
  final double uvIndex;
  final int humidity;
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.condition,
    required this.tempMax,
    required this.tempMin,
    required this.sunrise,
    required this.sunset,
    required this.uvIndexMax,
    required this.precipitationProbabilityMax,
    required this.windSpeedMax,
    required this.windDirectionDominant,
  });

  final DateTime date;
  final WeatherCondition condition;
  final double tempMax;
  final double tempMin;
  final DateTime sunrise;
  final DateTime sunset;
  final double uvIndexMax;
  final int precipitationProbabilityMax;
  final double windSpeedMax;
  final int windDirectionDominant;

  UvLevel get uvLevel => UvLevel.fromIndex(uvIndexMax);
  CompassPoint get windFrom => CompassPoint.fromDegrees(windDirectionDominant);
}

/// Current air quality from Open-Meteo's air-quality API.
class AirQuality {
  const AirQuality({required this.usAqi, this.pm25, this.pm10});

  final int usAqi;

  /// µg/m³.
  final double? pm25;
  final double? pm10;

  AqiLevel get level => AqiLevel.fromUsAqi(usAqi);
}

/// US EPA AQI categories.
enum AqiLevel {
  good,
  moderate,
  sensitive,
  unhealthy,
  veryUnhealthy,
  hazardous;

  static AqiLevel fromUsAqi(int aqi) => switch (aqi) {
    <= 50 => good,
    <= 100 => moderate,
    <= 150 => sensitive,
    <= 200 => unhealthy,
    <= 300 => veryUnhealthy,
    _ => hazardous,
  };
}

/// Who the forecast is for, beyond a healthy adult. Pollen isn't here:
/// Open-Meteo only models it for Europe.
enum HealthProfile { respiratory, children, elderly }

/// Where "too much" starts, tightened by the user's [HealthProfile]s (the
/// strictest one wins). Defaults are for a healthy adult; the sensitive
/// values follow EPA's AQI guidance and WHO's UV and heat advice.
class Limits {
  const Limits({this.aqi = 100, this.feelsHot = 35, this.uv = 6});

  factory Limits.of(Set<HealthProfile> health) => Limits(
    aqi: health.contains(HealthProfile.respiratory) ? 50 : 100,
    feelsHot:
        health.contains(HealthProfile.children) ||
            health.contains(HealthProfile.elderly)
        ? 33
        : 35,
    uv: health.contains(HealthProfile.children) ? 3 : 6,
  );

  /// US AQI above which to mask up and avoid hard exercise outdoors.
  final int aqi;

  /// Feels-like °C from which to warn about heat.
  final double feelsHot;

  /// UV index from which to warn about sun.
  final double uv;

  /// How much a hot hour counts against outdoor activities: the comfort
  /// limits in `scoreAt` drop by this many degrees for sensitive people.
  double get heatMargin => 35 - feelsHot;

  // Value equality, so `settingsProvider.select((s) => s.limits)` only
  // rebuilds when the limits change, not on every settings change.
  @override
  bool operator ==(Object other) =>
      other is Limits &&
      other.aqi == aqi &&
      other.feelsHot == feelsHot &&
      other.uv == uv;

  @override
  int get hashCode => Object.hash(aqi, feelsHot, uv);
}

/// Rule-based advice for the day, most important first.
enum WeatherTip {
  storm,
  umbrella,
  mask,
  hydrate,
  sunscreen,
  jacket,
  wind,

  /// Shown alone when no other rule fires.
  niceDay,
}

/// Up to [max] tips from the next 12 hours, current conditions and [air],
/// with thresholds from [limits].
List<WeatherTip> tipsFor(
  Weather weather,
  AirQuality? air, {
  int max = 3,
  Limits limits = const Limits(),
}) {
  final c = weather.current;
  final next = weather.next24Hours.take(12);
  const wet = {
    WeatherCondition.drizzle,
    WeatherCondition.rain,
    WeatherCondition.showers,
  };
  final today = weather.daily.firstOrNull;
  final tips = [
    if (next.any((h) => h.condition == WeatherCondition.thunderstorm))
      WeatherTip.storm,
    if (wet.contains(c.condition) ||
        next.any((h) => h.precipitationProbability >= 50))
      WeatherTip.umbrella,
    if (air != null && air.usAqi > limits.aqi) WeatherTip.mask,
    if (c.apparentTemperature >= limits.feelsHot) WeatherTip.hydrate,
    if (c.isDay && (today?.uvIndexMax ?? c.uvIndex) >= limits.uv)
      WeatherTip.sunscreen,
    if (c.apparentTemperature <= 12) WeatherTip.jacket,
    if (c.windSpeed >= 40) WeatherTip.wind,
  ];
  return tips.isEmpty ? const [WeatherTip.niceDay] : tips.take(max).toList();
}

/// Today's high minus yesterday's, in °C. Null without yesterday's data or
/// under 1.5°, a gap nobody notices.
double? highVsYesterday(Weather weather) {
  final (today, yesterday) = (weather.daily.firstOrNull, weather.yesterday);
  if (today == null || yesterday == null) return null;
  final delta = today.tempMax - yesterday.tempMax;
  return delta.abs() < 1.5 ? null : delta;
}

enum RainTrend {
  /// Dry now, rain in `minutes`.
  starting,

  /// Raining now, dry in `minutes`.
  stopping,

  /// Raining for the whole 2 hours.
  continuing,
}

/// Null when the next 2 hours are dry. 0.2 mm per 15 minutes is the lightest
/// rain that wets the ground; below it the model is mostly noise.
({RainTrend trend, int minutes})? rainOutlook(
  List<({DateTime time, double mm})> nowcast,
) {
  final wet = [for (final s in nowcast) s.mm >= 0.2];
  if (!wet.contains(true)) return null;
  const step = 15;
  if (!wet.first) {
    return (trend: RainTrend.starting, minutes: wet.indexOf(true) * step);
  }
  final dry = wet.indexOf(false);
  return dry == -1
      ? (trend: RainTrend.continuing, minutes: 0)
      : (trend: RainTrend.stopping, minutes: dry * step);
}
