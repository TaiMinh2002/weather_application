import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/errors.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../activities/domain/activity.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../weather/domain/entities/weather.dart';
import '../data/home_screen_widget.dart';

/// Hourly columns on the medium widget.
const widgetHours = 6;

/// What the native widgets show, already formatted: they have no access to
/// l10n or the settings. The small widget reads the first five keys; the
/// medium one also reads `activity` and `h<i>_time` / `_icon` / `_temp`.
/// Icons are a condition key ("rain_day"); each platform maps it to its own
/// symbol set.
Map<String, String> widgetData(
  Weather weather,
  String place,
  AppLocalizations l10n,
  AppSettings settings, {
  required String locale,
}) {
  final units = settings.units;
  final c = weather.current;
  final today = weather.daily.firstOrNull;
  final hm = DateFormat.Hm(locale);
  final activity = Activity.values
      .where(settings.activities.contains)
      .firstOrNull;
  final window = activity == null
      ? null
      : bestWindow(
          activity,
          weather.hourly,
          from: c.time,
          limits: settings.limits,
        );
  return {
    'city': place,
    'temp': units.formatTemp(c.temperature),
    'condition': c.condition.label(l10n),
    'hilo': today == null
        ? ''
        : l10n.hiLo(
            units.formatTemp(today.tempMax),
            units.formatTemp(today.tempMin),
          ),
    'sky': Sky.of(c.condition).key(isDay: c.isDay),
    // Only worth the room when it's actually a good time.
    'activity': activity != null && window != null && window.score >= 60
        ? l10n.morningActivity(
            l10n.activityName(activity.name),
            '${hm.format(window.from)}–${hm.format(window.to)}',
          )
        : '',
    // Clock times, not "Now": the widget only refreshes when the app does.
    for (final (i, h) in weather.next24Hours.take(widgetHours).indexed) ...{
      'h${i}_time': hm.format(h.time),
      'h${i}_icon': '${h.condition.name}_${h.isDay ? 'day' : 'night'}',
      'h${i}_temp': units.formatTemp(h.temperature),
    },
  };
}

/// Called with each fresh GPS forecast on Home.
Future<void> updateHomeScreenWidget(
  BuildContext context,
  WidgetRef ref,
  Weather weather,
  String place,
) {
  final data = widgetData(
    weather,
    place,
    context.l10n,
    ref.read(settingsProvider),
    locale: Localizations.localeOf(context).toString(),
  );
  final widget = ref.read(homeScreenWidgetProvider);
  // Platforms without the widget (web, desktop, iOS before the extension is
  // added) just skip it.
  return runQuietly(() => widget.update(data));
}
