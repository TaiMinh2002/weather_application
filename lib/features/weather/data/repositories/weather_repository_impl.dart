import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';
import '../../domain/entities/weather.dart';
import '../../domain/repositories/weather_repository.dart';
import '../datasources/weather_local_ds.dart';
import '../datasources/weather_remote_ds.dart';

part 'weather_repository_impl.g.dart';

/// Online: fetch and cache. Offline: last cached forecast, marked with
/// [Weather.cachedAt]. Neither: the network failure.
class WeatherRepositoryImpl implements WeatherRepository {
  const WeatherRepositoryImpl(this._remote, this._local);

  final WeatherRemoteDataSource _remote;
  final WeatherLocalDataSource _local;

  @override
  Future<Result<Weather>> getWeather({
    required double lat,
    required double lon,
  }) => guard(() async {
    try {
      final dto = await _remote.getForecast(lat, lon);
      await _local.save(lat, lon, dto, DateTime.now());
      return dto.toEntity();
    } on NetworkException {
      final cached = _local.read(lat, lon);
      if (cached == null) rethrow;
      final (dto, savedAt) = cached;
      return dto.toEntity(cachedAt: savedAt);
    }
  });
}

@Riverpod(keepAlive: true)
WeatherRepository weatherRepository(Ref ref) => WeatherRepositoryImpl(
  ref.watch(weatherRemoteDataSourceProvider),
  ref.watch(weatherLocalDataSourceProvider),
);
