import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/errors.dart';
import '../../../core/extensions/context_ext.dart';
import '../../activities/domain/activity.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../weather/domain/entities/weather.dart';
import '../data/morning_notifications.dart';

/// Re-arms the next mornings from [weather] (the GPS page's forecast) when
/// the setting is on. Called whenever fresh data arrives, so the week ahead
/// always carries the latest forecast.
Future<void> scheduleMorningForecast(
  BuildContext context,
  WidgetRef ref,
  Weather weather,
  String place,
) async {
  final settings = ref.read(settingsProvider);
  if (!settings.morningForecast) return;
  final l10n = context.l10n;
  final units = settings.units;
  final hm = DateFormat.Hm(Localizations.localeOf(context).toString());
  // One activity keeps the notification to a line or two.
  final activity = Activity.values
      .where(settings.activities.contains)
      .firstOrNull;
  String activityLine(DateTime day) {
    if (activity == null) return '';
    final w = bestWindow(
      activity,
      weather.hourly,
      from: day,
      limits: settings.limits,
    );
    if (w == null || w.score < 60) return '';
    final time = '${hm.format(w.from)}–${hm.format(w.to)}';
    return '\n${l10n.morningActivity(l10n.activityName(activity.name), time)}';
  }

  final items = [
    for (final slot in morningSlots([
      for (final d in weather.daily) d.date,
    ], DateTime.now()))
      if (weather.daily[slot.day] case final d)
        (
          at: slot.at,
          title: l10n.morningTitle(place),
          body:
              '${d.condition.label(l10n)} · '
              '${units.formatTemp(d.tempMin)} – ${units.formatTemp(d.tempMax)}'
              ' · ${l10n.rainChance('${d.precipitationProbabilityMax}%')}'
              '${activityLine(d.date)}',
        ),
  ];
  final notifications = ref.read(morningNotificationsProvider);
  await runQuietly(
    () => notifications.schedule(items, channelName: l10n.morningChannel),
  );
}
