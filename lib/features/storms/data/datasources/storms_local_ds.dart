import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/prefs.dart';
import '../models/storm_dto.dart';

part 'storms_local_ds.g.dart';

/// The last storm list fetched, as JSON in shared_preferences: storms are
/// when the network is most likely to go down, and when people most need
/// to see where one was heading. An empty list is saved too, so offline
/// "no storm" stays true instead of showing an older storm.
class StormsLocalDataSource {
  const StormsLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  Future<void> save(List<StormDto> storms, DateTime savedAt) =>
      _prefs.setString(
        PrefKeys.storms,
        jsonEncode({
          'savedAt': savedAt.toIso8601String(),
          'storms': [for (final s in storms) s.toJson()],
        }),
      );

  (List<StormDto>, DateTime)? read() {
    final raw = _prefs.getString(PrefKeys.storms);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        [
          for (final s in map['storms'] as List<dynamic>)
            StormDto.fromJson(s as Map<String, dynamic>),
        ],
        DateTime.parse(map['savedAt'] as String),
      );
    } catch (e) {
      // An entry written by an older app version no longer parses; treating
      // it as missing shows the real network error instead of a parse error.
      debugPrint('Ignoring unreadable storm cache: $e');
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
StormsLocalDataSource stormsLocalDataSource(Ref ref) =>
    StormsLocalDataSource(ref.watch(sharedPreferencesProvider));
