import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/weather_code_mapper.dart';
import '../../domain/entities/weather.dart';

part 'weather_dto.freezed.dart';
part 'weather_dto.g.dart';

/// Mirrors the `/forecast` response. Hourly/daily come as parallel arrays
/// (one list per variable), which [toEntity] zips into per-item objects.
@freezed
abstract class WeatherDto with _$WeatherDto {
  const WeatherDto._();

  const factory WeatherDto({
    required CurrentDto current,
    required HourlyDto hourly,
    required DailyDto daily,
  }) = _WeatherDto;

  factory WeatherDto.fromJson(Map<String, dynamic> json) =>
      _$WeatherDtoFromJson(json);

  Weather toEntity({DateTime? cachedAt}) => Weather(
    cachedAt: cachedAt,
    current: CurrentWeather(
      time: DateTime.parse(current.time),
      temperature: current.temperature,
      apparentTemperature: current.apparentTemperature,
      humidity: current.humidity,
      dewPoint: current.dewPoint,
      isDay: current.isDay == 1,
      condition: WeatherCondition.fromCode(current.weatherCode),
      windSpeed: current.windSpeed,
      windDirection: current.windDirection,
      pressure: current.pressure,
      uvIndex: current.uvIndex ?? 0,
      visibility: current.visibility ?? 0,
    ),
    hourly: [
      for (var i = 0; i < hourly.time.length; i++)
        HourlyForecast(
          time: DateTime.parse(hourly.time[i]),
          temperature: hourly.temperature[i],
          condition: WeatherCondition.fromCode(hourly.weatherCode[i]),
          precipitationProbability: hourly.precipitationProbability[i] ?? 0,
          isDay: hourly.isDay[i] == 1,
        ),
    ],
    daily: [
      for (var i = 0; i < daily.time.length; i++)
        DailyForecast(
          date: DateTime.parse(daily.time[i]),
          condition: WeatherCondition.fromCode(daily.weatherCode[i]),
          tempMax: daily.tempMax[i],
          tempMin: daily.tempMin[i],
          sunrise: DateTime.parse(daily.sunrise[i]),
          sunset: DateTime.parse(daily.sunset[i]),
          uvIndexMax: daily.uvIndexMax[i] ?? 0,
          precipitationProbabilityMax:
              daily.precipitationProbabilityMax[i] ?? 0,
          windSpeedMax: daily.windSpeedMax[i] ?? 0,
          windDirectionDominant: daily.windDirectionDominant[i] ?? 0,
        ),
    ],
  );
}

@freezed
abstract class CurrentDto with _$CurrentDto {
  const factory CurrentDto({
    required String time,
    @JsonKey(name: 'temperature_2m') required double temperature,
    @JsonKey(name: 'apparent_temperature') required double apparentTemperature,
    @JsonKey(name: 'relative_humidity_2m') required int humidity,
    @JsonKey(name: 'dew_point_2m') required double dewPoint,
    @JsonKey(name: 'is_day') required int isDay,
    @JsonKey(name: 'weather_code') required int weatherCode,
    @JsonKey(name: 'wind_speed_10m') required double windSpeed,
    @JsonKey(name: 'wind_direction_10m') required int windDirection,
    @JsonKey(name: 'pressure_msl') required double pressure,
    @JsonKey(name: 'uv_index') double? uvIndex,
    double? visibility,
  }) = _CurrentDto;

  factory CurrentDto.fromJson(Map<String, dynamic> json) =>
      _$CurrentDtoFromJson(json);
}

@freezed
abstract class HourlyDto with _$HourlyDto {
  const factory HourlyDto({
    required List<String> time,
    @JsonKey(name: 'temperature_2m') required List<double> temperature,
    @JsonKey(name: 'weather_code') required List<int> weatherCode,
    @JsonKey(name: 'precipitation_probability')
    required List<int?> precipitationProbability,
    @JsonKey(name: 'is_day') required List<int> isDay,
  }) = _HourlyDto;

  factory HourlyDto.fromJson(Map<String, dynamic> json) =>
      _$HourlyDtoFromJson(json);
}

@freezed
abstract class DailyDto with _$DailyDto {
  const factory DailyDto({
    required List<String> time,
    @JsonKey(name: 'weather_code') required List<int> weatherCode,
    @JsonKey(name: 'temperature_2m_max') required List<double> tempMax,
    @JsonKey(name: 'temperature_2m_min') required List<double> tempMin,
    required List<String> sunrise,
    required List<String> sunset,
    @JsonKey(name: 'uv_index_max') required List<double?> uvIndexMax,
    @JsonKey(name: 'precipitation_probability_max')
    required List<int?> precipitationProbabilityMax,
    @JsonKey(name: 'wind_speed_10m_max') required List<double?> windSpeedMax,
    @JsonKey(name: 'wind_direction_10m_dominant')
    required List<int?> windDirectionDominant,
  }) = _DailyDto;

  factory DailyDto.fromJson(Map<String, dynamic> json) =>
      _$DailyDtoFromJson(json);
}

/// `current` of the air-quality response. `us_aqi` is null where the model
/// has no coverage.
@freezed
abstract class AirQualityDto with _$AirQualityDto {
  const AirQualityDto._();

  const factory AirQualityDto({
    @JsonKey(name: 'us_aqi') int? usAqi,
    @JsonKey(name: 'pm2_5') double? pm25,
    double? pm10,
  }) = _AirQualityDto;

  factory AirQualityDto.fromJson(Map<String, dynamic> json) =>
      _$AirQualityDtoFromJson(json);

  AirQuality? toEntity() => switch (usAqi) {
    final aqi? => AirQuality(usAqi: aqi, pm25: pm25, pm10: pm10),
    null => null,
  };
}
