import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/prefs.dart';
import '../models/city_dto.dart';

part 'cities_local_ds.g.dart';

/// Saved cities, in the user's order, as a JSON list in shared_preferences.
class CitiesLocalDataSource {
  const CitiesLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  List<CityDto> read() {
    final raw = _prefs.getString(PrefKeys.savedCities);
    if (raw == null) return const [];
    try {
      return [
        for (final c in jsonDecode(raw) as List<dynamic>)
          CityDto.fromJson(c as Map<String, dynamic>),
      ];
    } catch (e) {
      // Unreadable data can't be recovered; starting empty keeps Home usable.
      debugPrint('Ignoring unreadable saved cities: $e');
      return const [];
    }
  }

  Future<void> write(List<CityDto> cities) =>
      _prefs.setString(PrefKeys.savedCities, jsonEncode(cities));
}

@Riverpod(keepAlive: true)
CitiesLocalDataSource citiesLocalDataSource(Ref ref) =>
    CitiesLocalDataSource(ref.watch(sharedPreferencesProvider));
