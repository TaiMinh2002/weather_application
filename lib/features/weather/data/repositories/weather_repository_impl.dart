import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';
import '../../domain/entities/weather.dart';
import '../../domain/repositories/weather_repository.dart';
import '../datasources/weather_remote_ds.dart';

part 'weather_repository_impl.g.dart';

// ponytail: remote only; Hive cache + offline fallback lands in plan.md day 7.
class WeatherRepositoryImpl implements WeatherRepository {
  const WeatherRepositoryImpl(this._remote);

  final WeatherRemoteDataSource _remote;

  @override
  Future<Result<Weather>> getWeather({
    required double lat,
    required double lon,
  }) => guard(() async => (await _remote.getForecast(lat, lon)).toEntity());
}

@Riverpod(keepAlive: true)
WeatherRepository weatherRepository(Ref ref) =>
    WeatherRepositoryImpl(ref.watch(weatherRemoteDataSourceProvider));
