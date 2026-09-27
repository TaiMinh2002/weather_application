import '../../../location/domain/entities/place.dart';

/// A geocoding result, also what the saved-cities list stores.
class City {
  const City({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.region,
    this.country,
  });

  /// Open-Meteo geocoding id; identifies the same city across searches.
  final int id;
  final String name;
  final double lat;
  final double lon;
  final String? region;
  final String? country;

  /// "Thừa Thiên Huế, Việt Nam"
  String get area => [region, country].nonNulls.join(', ');

  Place get place => Place(lat: lat, lon: lon, name: name);
}
