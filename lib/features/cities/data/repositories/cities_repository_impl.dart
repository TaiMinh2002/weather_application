import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';
import '../../domain/entities/city.dart';
import '../../domain/repositories/cities_repository.dart';
import '../datasources/cities_local_ds.dart';
import '../datasources/cities_remote_ds.dart';
import '../models/city_dto.dart';

part 'cities_repository_impl.g.dart';

class CitiesRepositoryImpl implements CitiesRepository {
  const CitiesRepositoryImpl(this._remote, this._local, this._locale);

  final CitiesRemoteDataSource _remote;
  final CitiesLocalDataSource _local;
  final Locale _locale;

  @override
  Future<Result<List<City>>> search(String query) => guard(() async {
    final dtos = await _remote.search(query, _locale.languageCode);
    return [for (final d in dtos) d.toEntity()];
  });

  @override
  List<City> savedCities() => [for (final d in _local.read()) d.toEntity()];

  @override
  Future<void> saveCities(List<City> cities) =>
      _local.write([for (final c in cities) CityDto.fromEntity(c)]);
}

// ponytail: device locale for city names; switch to the settings locale
// once the settings feature exists.
@Riverpod(keepAlive: true)
CitiesRepository citiesRepository(Ref ref) => CitiesRepositoryImpl(
  ref.watch(citiesRemoteDataSourceProvider),
  ref.watch(citiesLocalDataSourceProvider),
  PlatformDispatcher.instance.locale,
);
