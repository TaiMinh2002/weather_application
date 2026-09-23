/// A point to show weather for. Shared by GPS, city search and saved cities.
class Place {
  const Place({required this.lat, required this.lon, this.name});

  final double lat;
  final double lon;

  /// Null when reverse geocoding fails or is unsupported (web/desktop).
  final String? name;
}
