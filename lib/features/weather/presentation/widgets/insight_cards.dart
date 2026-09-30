import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../location/domain/entities/place.dart';
import '../../domain/entities/weather.dart';
import '../providers/weather_provider.dart';
import 'forecast_cards.dart';

// Home cards derived from the forecast and air quality rather than showing
// it directly.

/// Air quality is extra information: while it loads, fails, or isn't
/// covered for this location, the card is simply absent instead of pushing
/// a second error onto a page whose forecast loaded fine.
class AirQualityCard extends ConsumerWidget {
  const AirQualityCard({super.key, required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aq = ref.watch(airQualityProvider(lat, lon)).value;
    if (aq == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final text = context.textTheme;
    final colors = context.colors;
    final pm = [
      if (aq.pm25 case final v?) 'PM2.5 ${v.round()} µg/m³',
      if (aq.pm10 case final v?) 'PM10 ${v.round()} µg/m³',
    ].join(' · ');
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 6,
            children: [
              const Icon(Symbols.airwave_rounded, size: 20),
              Flexible(
                child: Text(
                  l10n.airQuality.toUpperCase(),
                  style: text.labelMedium?.copyWith(letterSpacing: 0.36),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 8,
            children: [
              Text('${aq.usAqi}', style: text.titleLarge),
              Flexible(
                child: Text(
                  l10n.aqiLevel(aq.level.name),
                  style: text.bodyLarge,
                ),
              ),
            ],
          ),
          _AqiBar(fraction: (aq.usAqi / 300).clamp(0, 1)),
          if (pm.isNotEmpty)
            Text(
              pm,
              style: text.bodyMedium?.copyWith(
                color: colors.onWeather.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }
}

/// The EPA colour scale with a dot at the current value.
class _AqiBar extends StatelessWidget {
  const _AqiBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    const dot = 12.0;
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: dot,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: aqiScale,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Positioned(
              left: (box.maxWidth - dot) * fraction,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: context.colors.onWeather,
                  shape: BoxShape.circle,
                  // Keeps the white dot visible over the yellow band.
                  boxShadow: [
                    BoxShadow(
                      color: context.colorScheme.shadow.withValues(alpha: 0.35),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only when [rainOutlook] finds rain in the next 2 hours: one bar per
/// 15 minutes under the summary sentence.
class NowcastCard extends StatelessWidget {
  const NowcastCard({super.key, required this.slots, required this.outlook});

  final List<({DateTime time, double mm})> slots;
  final ({RainTrend trend, int minutes}) outlook;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final colors = context.colors;
    final time = DateFormat.Hm(Localizations.localeOf(context).toString());
    // 1 mm in 15 minutes is already heavy rain; scale up only past it.
    final top = slots.map((s) => s.mm).fold(1.0, math.max);
    final muted = text.labelSmall?.copyWith(
      color: colors.onWeather.withValues(alpha: 0.75),
    );
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 6,
            children: [
              const Icon(Symbols.rainy_rounded, size: 20),
              Flexible(
                child: Text(
                  l10n.nowcastTitle.toUpperCase(),
                  style: text.labelMedium?.copyWith(letterSpacing: 0.36),
                ),
              ),
            ],
          ),
          Text(
            l10n.rainOutlook(outlook.trend.name, outlook.minutes),
            style: text.bodyLarge,
          ),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 6,
              children: [
                for (final s in slots)
                  Expanded(
                    child: FractionallySizedBox(
                      // A sliver even when dry, so the timeline stays readable.
                      heightFactor: math.max(s.mm / top, 0.06),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.onWeather.withValues(
                            alpha: s.mm >= 0.2 ? 0.9 : 0.35,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (slots.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.now, style: muted),
                Text(time.format(slots.last.time), style: muted),
              ],
            ),
        ],
      ),
    );
  }
}

/// Rule-based advice ([tipsFor]). The mask tip appears once air quality
/// loads; the card doesn't wait for it.
class TipsCard extends ConsumerWidget {
  const TipsCard({super.key, required this.weather, this.place});

  final Weather weather;

  /// Where to read air quality from; null (the skeleton) skips it.
  final Place? place;

  static IconData iconFor(WeatherTip tip) => switch (tip) {
    WeatherTip.storm => Symbols.thunderstorm_rounded,
    WeatherTip.umbrella => Symbols.umbrella_rounded,
    WeatherTip.mask => Symbols.masks_rounded,
    WeatherTip.hydrate => Symbols.water_full_rounded,
    WeatherTip.sunscreen => Symbols.light_mode_rounded,
    WeatherTip.jacket => Symbols.checkroom_rounded,
    WeatherTip.wind => Symbols.air_rounded,
    WeatherTip.niceDay => Symbols.directions_walk_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final place = this.place;
    final air = place == null
        ? null
        : ref.watch(airQualityProvider(place.lat, place.lon)).value;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 6,
            children: [
              const Icon(Symbols.tips_and_updates_rounded, size: 20),
              Flexible(
                child: Text(
                  l10n.tipsTitle.toUpperCase(),
                  style: text.labelMedium?.copyWith(letterSpacing: 0.36),
                ),
              ),
            ],
          ),
          for (final tip in tipsFor(weather, air))
            Row(
              spacing: 12,
              children: [
                Icon(iconFor(tip), size: 20),
                Expanded(
                  child: Text(
                    l10n.weatherTip(tip.name),
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
