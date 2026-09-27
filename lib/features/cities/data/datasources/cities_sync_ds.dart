import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/city_dto.dart';

part 'cities_sync_ds.g.dart';

/// Cloud backup of the saved-cities list: one row per anonymous user in
/// `saved_cities` (schema and RLS in supabase/schema.sql).
class CitiesSyncDataSource {
  const CitiesSyncDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'saved_cities';

  /// No login screen: each install signs in anonymously once and the session
  /// is kept on the device.
  Future<String> _userId() async {
    final user =
        _client.auth.currentUser ??
        (await _client.auth.signInAnonymously()).user;
    if (user == null) throw const AuthException('Anonymous sign-in failed');
    return user.id;
  }

  /// Null when this user has never backed anything up.
  Future<List<CityDto>?> pull() async {
    final row = await _client
        .from(_table)
        .select('cities')
        .eq('user_id', await _userId())
        .maybeSingle();
    if (row == null) return null;
    return [
      for (final c in row['cities'] as List<dynamic>)
        CityDto.fromJson(c as Map<String, dynamic>),
    ];
  }

  Future<void> push(List<CityDto> cities) async {
    await _client.from(_table).upsert({
      'user_id': await _userId(),
      'cities': [for (final c in cities) c.toJson()],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

/// Null when the app was built without Supabase keys.
@Riverpod(keepAlive: true)
CitiesSyncDataSource? citiesSyncDataSource(Ref ref) => ApiConstants.hasSupabase
    ? CitiesSyncDataSource(Supabase.instance.client)
    : null;
