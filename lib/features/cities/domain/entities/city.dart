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

  /// A point picked on the map, which has no geocoding id. The id is negative
  /// (Open-Meteo ids are positive) and fixed per ~1 km cell, so picking the
  /// same spot twice doesn't save it twice.
  factory City.fromPlace(Place place, {required String fallbackName}) => City(
    id:
        -(((place.lat + 90) * 100).round() * 100000 +
            ((place.lon + 180) * 100).round()),
    name: place.name ?? fallbackName,
    lat: place.lat,
    lon: place.lon,
  );

  /// "Thừa Thiên Huế, Việt Nam"
  String get area => [region, country].nonNulls.join(', ');

  Place get place => Place(lat: lat, lon: lon, name: name);
}
