import '../../../../core/error/errors.dart';
import '../entities/weather.dart';

abstract interface class WeatherRepository {
  Future<Result<Weather>> getWeather({
    required double lat,
    required double lon,
  });

  /// Null where Open-Meteo has no air-quality coverage.
  Future<Result<AirQuality?>> getAirQuality({
    required double lat,
    required double lon,
  });
}
