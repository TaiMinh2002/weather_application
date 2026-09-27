import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/city.dart';
import '../../domain/repositories/cities_repository.dart';
import '../datasources/cities_local_ds.dart';
import '../datasources/cities_remote_ds.dart';
import '../datasources/cities_sync_ds.dart';
import '../models/city_dto.dart';

part 'cities_repository_impl.g.dart';

/// The device list is the source of truth; the cloud copy is a best-effort
/// backup, so sync failures (offline, no keys, sign-in off) never surface.
class CitiesRepositoryImpl implements CitiesRepository {
  const CitiesRepositoryImpl(
    this._remote,
    this._local,
    this._locale,
    this._sync,
  );

  final CitiesRemoteDataSource _remote;
  final CitiesLocalDataSource _local;
  final Locale _locale;

  /// Null when the app is built without Supabase keys.
  final CitiesSyncDataSource? _sync;

  @override
  Future<Result<List<City>>> search(String query) => guard(() async {
    final dtos = await _remote.search(query, _locale.languageCode);
    return [for (final d in dtos) d.toEntity()];
  });

  @override
  List<City> savedCities() => [for (final d in _local.read()) d.toEntity()];

  @override
  Future<void> saveCities(List<City> cities) async {
    final dtos = [for (final c in cities) CityDto.fromEntity(c)];
    await _local.write(dtos);
    await _backup(() => _sync?.push(dtos));
  }

  @override
  Future<List<City>?> syncOnStart() async {
    final sync = _sync;
    if (sync == null) return null;
    final local = _local.read();
    if (local.isNotEmpty) {
      await _backup(() => sync.push(local));
      return null;
    }
    List<CityDto>? cloud;
    await _backup(() async => cloud = await sync.pull());
    final restored = cloud;
    if (restored == null || restored.isEmpty) return null;
    await _local.write(restored);
    return [for (final d in restored) d.toEntity()];
  }

  Future<void> _backup(Future<void>? Function() call) async {
    try {
      await call();
    } catch (e) {
      // Backup only: the local list is already saved and the next change
      // or launch retries.
      debugPrint('Saved-cities sync skipped: $e');
    }
  }
}

@Riverpod(keepAlive: true)
CitiesRepository citiesRepository(Ref ref) => CitiesRepositoryImpl(
  ref.watch(citiesRemoteDataSourceProvider),
  ref.watch(citiesLocalDataSourceProvider),
  ref.watch(settingsProvider.select((s) => s.effectiveLocale)),
  ref.watch(citiesSyncDataSourceProvider),
);
