import 'dart:math' as math;

/// A tropical cyclone as JMA (RSMC Tokyo, the WMO centre for the western
/// North Pacific and the South China Sea) reports it.
class Storm {
  const Storm({
    required this.id,
    required this.name,
    required this.issuedAt,
    required this.points,
    required this.track,
    this.cachedAt,
  });

  /// Set when the network failed and this came from the offline copy.
  final DateTime? cachedAt;

  /// JMA's id, e.g. "TC2632"; stable for the storm's life.
  final String id;

  /// International name ("Surigae"); null while it's still a depression.
  final String? name;
  final DateTime issuedAt;

  /// Now first, then each forecast time.
  final List<StormPoint> points;

  /// Past positions, oldest first.
  final List<({double lat, double lon})> track;

  StormPoint get now => points.first;
}

class StormPoint {
  const StormPoint({
    required this.time,
    required this.hoursAhead,
    required this.lat,
    required this.lon,
    this.windMs,
    this.gustMs,
    this.pressure,
    this.radiusKm,
    this.isLow = false,
  });

  /// UTC.
  final DateTime time;
  final int hoursAhead;
  final double lat;
  final double lon;

  /// 10-minute sustained wind, m/s.
  final double? windMs;
  final double? gustMs;

  /// hPa.
  final int? pressure;

  /// 70% probability circle around a forecast centre.
  final double? radiusKm;

  /// Forecast to have become an ordinary (extratropical) low by then.
  final bool isLow;
}

/// Beaufort force for a wind speed in m/s, the "cấp gió" Vietnamese
/// forecasts use. Extended past 12 to 17, as Vietnam does for storms.
int beaufort(double ms) {
  const upper = [
    0.2, 1.5, 3.3, 5.4, 7.9, 10.7, 13.8, 17.1, 20.7, 24.4, 28.4, 32.6, //
    36.9, 41.4, 46.1, 50.9, 56.0,
  ];
  final i = upper.indexWhere((u) => ms <= u);
  return i == -1 ? 17 : i;
}

/// Vietnam's cyclone classes (Decision 18/2021/QĐ-TTg), by the Beaufort
/// force of the sustained wind.
enum StormStrength {
  depression,
  storm,
  severe,
  veryStrong,
  superTyphoon;

  static StormStrength? of(double? windMs) => switch (windMs) {
    null => null,
    final ms => switch (beaufort(ms)) {
      < 6 => null,
      <= 7 => depression,
      <= 9 => storm,
      <= 11 => severe,
      <= 15 => veryStrong,
      _ => superTyphoon,
    },
  };
}

/// Great-circle distance in km.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 6371 * 2 * math.asin(math.sqrt(a));
}

/// The now-or-forecast point that comes nearest to (lat, lon).
({StormPoint point, double km}) closestApproach(
  Storm storm,
  double lat,
  double lon,
) => storm.points
    .map((p) => (point: p, km: distanceKm(p.lat, p.lon, lat, lon)))
    .reduce((a, b) => b.km < a.km ? b : a);

/// Storms that are, or are forecast to come, within [maxKm] of (lat, lon),
/// nearest first. 1500 km reaches from central Vietnam to the Philippines,
/// where most storms that hit Vietnam are first seen, a few days out.
List<Storm> stormsNear(
  List<Storm> storms,
  double lat,
  double lon, {
  double maxKm = 1500,
}) {
  final near = [
    for (final s in storms)
      if (closestApproach(s, lat, lon) case final c when c.km <= maxKm)
        (storm: s, km: c.km),
  ]..sort((a, b) => a.km.compareTo(b.km));
  return [for (final n in near) n.storm];
}
