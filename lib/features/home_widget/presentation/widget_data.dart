import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/errors.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../weather/domain/entities/weather.dart';
import '../data/home_screen_widget.dart';

/// What the native widget shows, already formatted: it has no access to l10n
/// or the unit settings.
Map<String, String> widgetData(
  Weather weather,
  String place,
  AppLocalizations l10n,
  Units units,
) {
  final c = weather.current;
  final today = weather.daily.firstOrNull;
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
    ref.read(settingsProvider).units,
  );
  final widget = ref.read(homeScreenWidgetProvider);
  // Platforms without the widget (web, desktop, iOS before the extension is
  // added) just skip it.
  return runQuietly(() => widget.update(data));
}
