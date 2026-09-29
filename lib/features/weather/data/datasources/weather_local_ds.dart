import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/prefs.dart';
import '../models/weather_dto.dart';

part 'weather_local_ds.g.dart';

/// Last successful forecast per location, as JSON in shared_preferences.
/// ponytail: one ~13 KB entry per location; move to a real store (Hive/file)
/// if saved cities grow past a handful.
class WeatherLocalDataSource {
  const WeatherLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// ~1 km grid, so GPS jitter between launches still hits the same entry.
  static String _key(double lat, double lon) =>
      'weather:${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

  Future<void> save(double lat, double lon, WeatherDto dto, DateTime savedAt) =>
      _prefs.setString(
        _key(lat, lon),
        jsonEncode({'savedAt': savedAt.toIso8601String(), 'data': dto}),
      );

  (WeatherDto, DateTime)? read(double lat, double lon) {
    final raw = _prefs.getString(_key(lat, lon));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        WeatherDto.fromJson(map['data'] as Map<String, dynamic>),
        DateTime.parse(map['savedAt'] as String),
      );
    } catch (e) {
      // An entry written by an older app version no longer parses; treating
      // it as missing shows the real network error instead of a parse error.
      debugPrint('Ignoring unreadable weather cache: $e');
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
WeatherLocalDataSource weatherLocalDataSource(Ref ref) =>
    WeatherLocalDataSource(ref.watch(sharedPreferencesProvider));
