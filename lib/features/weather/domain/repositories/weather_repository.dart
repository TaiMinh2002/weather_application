import '../../../../core/error/errors.dart';
import '../entities/weather.dart';

abstract interface class WeatherRepository {
  Future<Result<Weather>> getWeather({
    required double lat,
    required double lon,
  });
}
