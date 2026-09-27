import '../../../../core/utils/weather_code_mapper.dart';

/// Units are Open-Meteo defaults: °C, km/h, hPa, metres. Convert in the UI.
/// Times are local to the forecast location (timezone=auto).
class Weather {
  const Weather({
    required this.current,
    required this.hourly,
    required this.daily,
    this.cachedAt,
  });

  final CurrentWeather current;

  /// All hours for the forecast range (7 days); see [next24Hours].
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

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
  });

  final DateTime time;
  final double temperature;
  final WeatherCondition condition;
  final int precipitationProbability;
  final bool isDay;
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
  });

  final DateTime date;
  final WeatherCondition condition;
  final double tempMax;
  final double tempMin;
  final DateTime sunrise;
  final DateTime sunset;
  final double uvIndexMax;
  final int precipitationProbabilityMax;
}
