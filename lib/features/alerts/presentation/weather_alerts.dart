import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/errors.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/utils/unit_converter.dart';
import '../../location/domain/entities/place.dart';
import '../../location/presentation/providers/location_provider.dart';
import '../../notifications/data/morning_notifications.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../data/alerts_sync_ds.dart';

/// Same id the Edge Function puts in `android.notification.channel_id`.
const alertsChannelId = 'weather_alerts';

/// Sends the current GPS place and alert choices to the server, when alerts
/// are on. Called with each fresh GPS forecast, so the server follows the
/// user around; failures only mean the server has a slightly older place.
Future<void> syncWeatherAlerts(WidgetRef ref, Place place) async {
  final settings = ref.read(settingsProvider);
  final sync = ref.read(alertsSyncDataSourceProvider);
  if (sync == null || !settings.weatherAlerts) return;
  await runQuietly(
    () => sync.upsert(
      lat: place.lat,
      lon: place.lon,
      locale: settings.effectiveLocale.languageCode,
      fahrenheit: settings.units.temp == TempUnit.fahrenheit,
      types: settings.alertTypes,
    ),
  );
}

/// Settings switch: asks for permission on the way on and removes the
/// subscription on the way off, so the server stops checking this device.
Future<void> setWeatherAlerts(
  BuildContext context,
  WidgetRef ref,
  bool on,
) async {
  final sync = ref.read(alertsSyncDataSourceProvider);
  final settings = ref.read(settingsProvider.notifier);
  if (sync == null) return;
  if (!on) {
    await settings.setWeatherAlerts(false);
    await runQuietly(sync.delete);
    return;
  }
  if (!await sync.requestPermission()) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.notificationsDenied)));
    }
    return;
  }
  if (context.mounted) {
    await runQuietly(
      () => ref
          .read(morningNotificationsProvider)
          .createChannel(alertsChannelId, context.l10n.weatherAlerts),
    );
  }
  await settings.setWeatherAlerts(true);
  await resyncWeatherAlerts(ref);
}

/// After a setting the server words or filters alerts by (language, units,
/// alert types): pushes it now instead of at the next GPS refresh. Uses the
/// place Home already loaded; before that there's nothing to sync yet.
Future<void> resyncWeatherAlerts(WidgetRef ref) async {
  if (ref.read(currentPlaceProvider).value case final place?) {
    await syncWeatherAlerts(ref, place);
  }
}

Future<void> setAlertType(WidgetRef ref, AlertType type, bool on) async {
  final settings = ref.read(settingsProvider);
  await ref
      .read(settingsProvider.notifier)
      .setAlertTypes(
        on
            ? {...settings.alertTypes, type}
            : ({...settings.alertTypes}..remove(type)),
      );
  await resyncWeatherAlerts(ref);
}

/// Android shows nothing for a push that arrives while the app is open, so
/// it's re-posted locally. iOS shows it itself (see main.dart). Null when
/// alerts aren't built in.
StreamSubscription<RemoteMessage>? showForegroundAlerts(
  BuildContext context,
  WidgetRef ref,
) {
  if (ref.read(alertsSyncDataSourceProvider) == null ||
      defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  final channelName = context.l10n.weatherAlerts;
  return FirebaseMessaging.onMessage.listen((message) {
    final n = message.notification;
    if (n == null) return;
    runQuietly(
      () => ref
          .read(morningNotificationsProvider)
          .show(
            id: message.messageId.hashCode,
            title: n.title ?? '',
            body: n.body ?? '',
            channelId: alertsChannelId,
            channelName: channelName,
          ),
    );
  });
}
