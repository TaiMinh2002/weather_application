import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/timezone.dart' as tz;

part 'morning_notifications.g.dart';

/// One morning notification: when it fires and which forecast day it shows.
typedef MorningSlot = ({DateTime at, int day});

/// Morning slots still ahead of [now], one per forecast day (index into
/// `Weather.daily`). Each notification shows its own day's forecast, so
/// scheduling a week at once needs no background refresh.
List<MorningSlot> morningSlots(
  List<DateTime> days,
  DateTime now, {
  int hour = 7,
}) => [
  for (final (i, d) in days.indexed)
    if (DateTime(d.year, d.month, d.day, hour).isAfter(now))
      (at: DateTime(d.year, d.month, d.day, hour), day: i),
];

/// Wraps the notification plugin for the morning forecast.
class MorningNotifications {
  MorningNotifications(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Seven ids, one per forecast day; nothing else in the app notifies.
  static const _firstId = 700;
  static const _slots = 7;

  /// Initialised on first use, so app startup doesn't wait for it.
  late final Future<void> _ready = _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      // Asked for only when the user turns the setting on.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  Future<bool> requestPermission() async {
    await _ready;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, sound: true);
    return granted ?? false;
  }

  /// Replaces whatever was scheduled before.
  Future<void> schedule(
    List<({DateTime at, String title, String body})> items, {
    required String channelName,
  }) async {
    await _ready;
    await cancel();
    for (final (i, item) in items.take(_slots).indexed) {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_forecast',
          channelName,
          // The body can carry a second line (best activity time), which the
          // default style cuts off.
          styleInformation: BigTextStyleInformation(item.body),
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await _plugin.zonedSchedule(
        id: _firstId + i,
        // An absolute instant, so no device time-zone lookup is needed.
        scheduledDate: tz.TZDateTime.from(item.at.toUtc(), tz.UTC),
        notificationDetails: details,
        // Inexact avoids the exact-alarm permission; a few minutes late is
        // fine for a morning summary.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: item.title,
        body: item.body,
      );
    }
  }

  /// A push alert that arrived while the app was open: Android doesn't show
  /// those itself. [channelId] matches the one the server sends to.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    await _ready;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Created up front so pushes that arrive in the background land in a
  /// named, high-importance channel instead of Android's default one.
  Future<void> createChannel(String id, String name) async {
    await _ready;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(id, name, importance: Importance.high),
        );
  }

  Future<void> cancel() async {
    await _ready;
    for (var i = 0; i < _slots; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }
}

@Riverpod(keepAlive: true)
MorningNotifications morningNotifications(Ref ref) =>
    MorningNotifications(FlutterLocalNotificationsPlugin());
