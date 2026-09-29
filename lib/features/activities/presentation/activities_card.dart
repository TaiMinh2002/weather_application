import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/extensions/context_ext.dart';
import '../../location/domain/entities/place.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../weather/domain/entities/weather.dart';
import '../../weather/presentation/providers/weather_provider.dart';
import '../../weather/presentation/widgets/forecast_cards.dart';
import '../domain/activity.dart';

IconData _icon(Activity a) => switch (a) {
  Activity.motorbike => Symbols.two_wheeler_rounded,
  Activity.laundry => Symbols.local_laundry_service_rounded,
  Activity.running => Symbols.directions_run_rounded,
  Activity.cycling => Symbols.directions_bike_rounded,
  Activity.carWash => Symbols.local_car_wash_rounded,
  Activity.picnic => Symbols.park_rounded,
};

/// The best time today for each activity the user picked. Once today has no
/// room left for one (evening), it shows tomorrow's instead.
class ActivitiesCard extends ConsumerWidget {
  const ActivitiesCard({super.key, required this.weather, this.place});

  final Weather weather;

  /// Where to read air quality from; null (the skeleton) skips it.
  final Place? place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final selected = ref.watch(settingsProvider.select((s) => s.activities));
    final place = this.place;
    final air = place == null
        ? null
        : ref.watch(airQualityProvider(place.lat, place.lon)).value;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 6,
            children: [
              const Icon(Symbols.event_available_rounded, size: 20),
              Expanded(
                child: Text(
                  l10n.activitiesTitle.toUpperCase(),
                  style: text.labelMedium?.copyWith(letterSpacing: 0.36),
                ),
              ),
              IconButton(
                tooltip: l10n.activitiesEdit,
                onPressed: () => _pickActivities(context),
                icon: const Icon(Symbols.tune_rounded, size: 20),
              ),
            ],
          ),
          if (selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(l10n.activitiesEmpty, style: text.bodyMedium),
            )
          else
            for (final a in Activity.values)
              if (selected.contains(a))
                _ActivityRow(activity: a, weather: weather, air: air),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.weather,
    required this.air,
  });

  final Activity activity;
  final Weather weather;
  final AirQuality? air;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final hm = DateFormat.Hm(Localizations.localeOf(context).toString());
    final now = weather.current.time;
    final today = bestWindow(activity, weather.hourly, from: now, air: air);
    // Today's AQI says little about tomorrow, so it's left out there.
    final window =
        today ??
        bestWindow(
          activity,
          weather.hourly,
          from: DateTime(now.year, now.month, now.day + 1),
        );
    final level = ActivityLevel.fromScore(window?.score ?? 0);
    final String when;
    if (window == null || level == ActivityLevel.poor) {
      when = l10n.activityNoGoodTime;
    } else {
      final range = '${hm.format(window.from)}–${hm.format(window.to)}';
      when = today == null ? l10n.activityTomorrow(range) : range;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        spacing: 12,
        children: [
          Icon(_icon(activity), size: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.activityName(activity.name), style: text.bodyMedium),
                Opacity(
                  opacity: 0.8,
                  child: Text(when, style: text.labelMedium),
                ),
              ],
            ),
          ),
          Text(l10n.activityLevel(level.name), style: text.labelLarge),
        ],
      ),
    );
  }
}

Future<void> _pickActivities(BuildContext context) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final selected = ref.watch(settingsProvider.select((s) => s.activities));
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Text(
                context.l10n.activitiesEdit,
                style: context.textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in Activity.values)
                    FilterChip(
                      avatar: Icon(_icon(a), size: 18),
                      label: Text(context.l10n.activityName(a.name)),
                      selected: selected.contains(a),
                      onSelected: (on) => ref
                          .read(settingsProvider.notifier)
                          .setActivities(
                            on ? {...selected, a} : ({...selected}..remove(a)),
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ),
);
