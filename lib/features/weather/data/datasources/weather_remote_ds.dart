import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/weather_dto.dart';

part 'weather_remote_ds.g.dart';

class WeatherRemoteDataSource {
  const WeatherRemoteDataSource(this._dio);

  final Dio _dio;

  Future<WeatherDto> getForecast(double lat, double lon) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,dew_point_2m,'
              'is_day,weather_code,wind_speed_10m,wind_direction_10m,'
              'pressure_msl,uv_index,visibility',
          'hourly':
              'temperature_2m,weather_code,precipitation_probability,is_day,'
              'apparent_temperature,precipitation,wind_speed_10m,uv_index,'
              'relative_humidity_2m',
          'daily':
              'weather_code,temperature_2m_max,temperature_2m_min,sunrise,'
              'sunset,uv_index_max,precipitation_probability_max,'
              'wind_speed_10m_max,wind_direction_10m_dominant',
          'minutely_15': 'precipitation',
          'forecast_minutely_15': 8,
          'timezone': 'auto',
          'forecast_days': 7,
          // Only for the "warmer than yesterday" line; the mapper splits it
          // off so `daily` still starts today.
          'past_days': 1,
        },
      );
      return WeatherDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw e.toAppException();
    }
  }

  Future<AirQualityDto> getAirQuality(double lat, double lon) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiConstants.airQualityBaseUrl}/air-quality',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'us_aqi,pm2_5,pm10',
        },
      );
      return AirQualityDto.fromJson(
        res.data!['current'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw e.toAppException();
    }
  }
}

@Riverpod(keepAlive: true)
WeatherRemoteDataSource weatherRemoteDataSource(Ref ref) =>
    WeatherRemoteDataSource(ref.watch(dioProvider));
