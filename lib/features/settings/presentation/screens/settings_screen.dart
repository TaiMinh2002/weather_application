import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/error/errors.dart';
import '../../../../core/extensions/context_ext.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../alerts/data/alerts_sync_ds.dart';
import '../../../alerts/presentation/weather_alerts.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../notifications/data/morning_notifications.dart';
import '../../../notifications/presentation/morning_forecast.dart';
import '../../../weather/domain/entities/weather.dart';
import '../../../weather/presentation/providers/weather_provider.dart';
import '../providers/settings_provider.dart';

/// Every change applies immediately, so there is no Save button.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Group(
            title: l10n.units,
            rows: [
              _Row(
                label: l10n.temperature,
                trailing: _Segmented(
                  selected: settings.units.temp,
                  onSelected: (unit) async {
                    await notifier.setTempUnit(unit);
                    await resyncWeatherAlerts(ref);
                  },
                  options: const [
                    (TempUnit.celsius, '°C', null),
                    (TempUnit.fahrenheit, '°F', null),
                  ],
                ),
              ),
              _Row(
                label: l10n.windSpeed,
                trailing: _Segmented(
                  selected: settings.units.wind,
                  onSelected: notifier.setWindUnit,
                  options: const [
                    (WindUnit.kmh, 'km/h', null),
                    (WindUnit.ms, 'm/s', null),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Group(
            title: l10n.appearance,
            rows: [
              _Row(
                label: l10n.theme,
                trailing: _Segmented(
                  selected: settings.themeMode,
                  onSelected: notifier.setThemeMode,
                  options: [
                    (
                      ThemeMode.light,
                      l10n.themeLight,
                      Symbols.light_mode_rounded,
                    ),
                    (ThemeMode.dark, l10n.themeDark, Symbols.dark_mode_rounded),
                    (
                      ThemeMode.system,
                      l10n.themeSystem,
                      Symbols.routine_rounded,
                    ),
                  ],
                ),
              ),
              _Row(
                label: l10n.language,
                trailing: _Segmented(
                  // Unset follows the device; show what the UI resolved to.
                  selected:
                      settings.locale?.languageCode ??
                      Localizations.localeOf(context).languageCode,
                  // Alerts are worded on the server in this language.
                  onSelected: (code) async {
                    await notifier.setLanguage(code);
                    await resyncWeatherAlerts(ref);
                  },
                  // Language names are written in their own language, so a
                  // user can find theirs whatever the UI language is.
                  options: const [
                    ('vi', 'Tiếng Việt', null),
                    ('en', 'English', null),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Group(
            title: l10n.health,
            rows: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Text(
                      l10n.healthHint,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in HealthProfile.values)
                          FilterChip(
                            label: Text(l10n.healthProfile(p.name)),
                            selected: settings.health.contains(p),
                            onSelected: (on) async {
                              await notifier.setHealth(
                                on
                                    ? {...settings.health, p}
                                    : ({...settings.health}..remove(p)),
                              );
                              // The server's alert thresholds follow it too.
                              await resyncWeatherAlerts(ref);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Group(
            title: l10n.notifications,
            rows: [
              _Row(
                label: l10n.morningForecast,
                trailing: Switch(
                  value: settings.morningForecast,
                  onChanged: (on) => _setMorningForecast(context, ref, on),
                ),
              ),
              if (ref.watch(alertsSyncDataSourceProvider) != null) ...[
                _Row(
                  label: l10n.weatherAlerts,
                  trailing: Switch(
                    value: settings.weatherAlerts,
                    onChanged: (on) => setWeatherAlerts(context, ref, on),
                  ),
                ),
                if (settings.weatherAlerts)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in AlertType.values)
                          FilterChip(
                            label: Text(l10n.alertType(type.name)),
                            selected: settings.alertTypes.contains(type),
                            onSelected: (on) => setAlertType(ref, type, on),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _Group(
            title: l10n.about,
            rows: [
              _Row(
                label: l10n.weatherData,
                icon: Symbols.cloud_rounded,
                trailing: Text(
                  'Open-Meteo',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for permission on the way on; schedules straight away from the GPS
/// forecast Home already loaded, instead of waiting for the next refresh.
Future<void> _setMorningForecast(
  BuildContext context,
  WidgetRef ref,
  bool on,
) async {
  final notifications = ref.read(morningNotificationsProvider);
  final settings = ref.read(settingsProvider.notifier);
  if (!on) {
    await settings.setMorningForecast(false);
    await runQuietly(notifications.cancel);
    return;
  }
  if (!await notifications.requestPermission()) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.notificationsDenied)));
    }
    return;
  }
  await settings.setMorningForecast(true);
  final place = ref.read(currentPlaceProvider).value;
  final weather = place == null
      ? null
      : ref.read(weatherProvider(place.lat, place.lon)).value;
  if (place != null && weather != null && context.mounted) {
    await scheduleMorningForecast(
      context,
      ref,
      weather,
      place.name ?? context.l10n.currentLocation,
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 10,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          title.toUpperCase(),
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colors.textMuted,
            letterSpacing: 0.48,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const Divider(),
              row,
            ],
          ],
        ),
      ),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing, this.icon});

  final String label;
  final Widget trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // The label keeps its natural width (up to half the row) so it doesn't
      // wrap; the control takes the rest and scales down on narrow screens.
      child: LayoutBuilder(
        builder: (context, box) => Row(
          spacing: 12,
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: context.colors.textMuted),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
              child: Text(label, style: context.textTheme.bodyLarge),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pill segmented control from the design; Material's SegmentedButton is an
/// outlined style that doesn't match.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.selected,
    required this.onSelected,
    required this.options,
  });

  final T selected;
  final ValueChanged<T> onSelected;
  final List<(T, String, IconData?)> options;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final style = context.textTheme.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label, icon) in options)
            Semantics(
              button: true,
              selected: value == selected,
              child: Material(
                color: value == selected ? scheme.primary : context.colors.card,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onSelected(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        if (icon != null)
                          Icon(
                            icon,
                            size: 14,
                            color: value == selected
                                ? scheme.onPrimary
                                : context.colors.textMuted,
                          ),
                        Text(
                          label,
                          style: style?.copyWith(
                            color: value == selected
                                ? scheme.onPrimary
                                : context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
