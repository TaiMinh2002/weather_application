import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
              'temperature_2m,relative_humidity_2m,apparent_temperature,'
              'is_day,weather_code,wind_speed_10m,wind_direction_10m,'
              'pressure_msl,uv_index,visibility',
          'hourly':
              'temperature_2m,weather_code,precipitation_probability,is_day',
          'daily':
              'weather_code,temperature_2m_max,temperature_2m_min,sunrise,'
              'sunset,uv_index_max,precipitation_probability_max',
          'timezone': 'auto',
          'forecast_days': 7,
        },
      );
      return WeatherDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw e.toAppException();
    }
  }
}

@Riverpod(keepAlive: true)
WeatherRemoteDataSource weatherRemoteDataSource(Ref ref) =>
    WeatherRemoteDataSource(ref.watch(dioProvider));
