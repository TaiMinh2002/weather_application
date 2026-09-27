import 'dart:ui';

import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_ds.dart';

part 'location_repository_impl.g.dart';

class LocationRepositoryImpl implements LocationRepository {
  const LocationRepositoryImpl(this._ds, this._locale);

  final LocationDataSource _ds;
  final Locale _locale;

  @override
  Future<Result<Place>> getCurrentPlace() => guard(() async {
    if (!await _ds.isServiceEnabled()) {
      throw const LocationException(LocationError.serviceDisabled);
    }

    var permission = await _ds.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _ds.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied || LocationPermission.unableToDetermine:
        throw const LocationException(LocationError.denied);
      case LocationPermission.deniedForever:
        throw const LocationException(LocationError.deniedForever);
      case LocationPermission.whileInUse || LocationPermission.always:
        break;
    }

    final pos = await _ds.getPosition();
    return placeAt(pos.latitude, pos.longitude);
  });

  @override
  Future<Place> placeAt(double lat, double lon) async {
    String? name;
    try {
      name = await _ds.placeName(lat, lon, _locale);
    } catch (_) {
      // A missing city name must not block the weather; UI falls back.
    }
    return Place(lat: lat, lon: lon, name: name);
  }
}

@Riverpod(keepAlive: true)
LocationRepository locationRepository(Ref ref) => LocationRepositoryImpl(
  ref.watch(locationDataSourceProvider),
  ref.watch(settingsProvider.select((s) => s.effectiveLocale)),
);
