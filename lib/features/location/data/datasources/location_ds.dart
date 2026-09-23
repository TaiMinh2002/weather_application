import 'dart:ui';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';

part 'location_ds.g.dart';

/// Thin wrapper over the static plugin APIs so the repository can be mocked.
class LocationDataSource {
  const LocationDataSource();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<Position> getPosition() async {
    try {
      // City-level accuracy is enough for weather and is faster/cheaper.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      throw const LocationException(LocationError.unavailable);
    }
  }

  /// Created per call: `Geocoding()` throws on platforms without a plugin.
  Future<String?> placeName(double lat, double lon, Locale locale) async {
    final marks = await Geocoding().placemarkFromCoordinates(
      lat,
      lon,
      locale: locale,
    );
    if (marks.isEmpty) return null;
    final m = marks.first;
    return [
      m.locality,
      m.subAdministrativeArea,
      m.administrativeArea,
    ].firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);
  }
}

@Riverpod(keepAlive: true)
LocationDataSource locationDataSource(Ref ref) => const LocationDataSource();
