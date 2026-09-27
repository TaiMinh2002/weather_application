import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/errors.dart';
import '../../../core/extensions/context_ext.dart';
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
              ' · ${l10n.rainChance('${d.precipitationProbabilityMax}%')}',
        ),
  ];
  final notifications = ref.read(morningNotificationsProvider);
  await runQuietly(
    () => notifications.schedule(items, channelName: l10n.morningChannel),
  );
}
