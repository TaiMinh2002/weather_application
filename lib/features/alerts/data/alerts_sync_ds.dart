import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/supabase_session.dart';

part 'alerts_sync_ds.g.dart';

/// What the `check-alerts` Edge Function can push. Names are stored in the
/// `alert_subscriptions.types` column, so renaming one needs a migration.
enum AlertType { rain, uv, air, heat }

/// One `alert_subscriptions` row per anonymous user: where the device is and
/// what to alert about. The server does the checking (supabase/functions/
/// check-alerts), because the app can't run reliably in the background.
class AlertsSyncDataSource {
  const AlertsSyncDataSource(this._client, this._messaging);

  final SupabaseClient _client;
  final FirebaseMessaging _messaging;

  static const _table = 'alert_subscriptions';

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Rounded to ~1 km: enough for a rain alert, and the server stores no
  /// more precise location than it needs.
  Future<void> upsert({
    required double lat,
    required double lon,
    required String locale,
    required bool fahrenheit,
    required Set<AlertType> types,
    required Set<String> health,
  }) async {
    // On iOS the FCM token needs the APNs token, which arrives a moment after
    // permission is granted; without the wait, turning alerts on would only
    // register on the next launch.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var i = 0; i < 10 && await _messaging.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    final token = await _messaging.getToken();
    if (token == null) throw StateError('No FCM token yet');
    await _client.from(_table).upsert({
      'user_id': await _client.anonymousUserId(),
      'fcm_token': token,
      'lat': double.parse(lat.toStringAsFixed(2)),
      'lon': double.parse(lon.toStringAsFixed(2)),
      'locale': locale,
      'fahrenheit': fahrenheit,
      'types': [for (final t in types) t.name],
      'health': [...health],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> delete() async {
    await _client
        .from(_table)
        .delete()
        .eq('user_id', await _client.anonymousUserId());
  }
}

/// Null when the app was built without Supabase or Firebase keys.
@Riverpod(keepAlive: true)
AlertsSyncDataSource? alertsSyncDataSource(Ref ref) => ApiConstants.hasFirebase
    ? AlertsSyncDataSource(Supabase.instance.client, FirebaseMessaging.instance)
    : null;
