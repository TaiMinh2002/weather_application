import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/weather.dart';
import '../providers/weather_provider.dart';

// Forecast blocks drawn on the weather gradient: text and icon colors come
// from the surrounding theme, which the Home gradient page sets to onWeather.

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.colors.glass,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class HourlyCard extends ConsumerWidget {
  const HourlyCard({super.key, required this.hours});

  final List<HourlyForecast> hours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).units;
    final l10n = context.l10n;
    final text = context.textTheme;
    final time = DateFormat.Hm(Localizations.localeOf(context).toString());
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(l10n.hourlyTitle, style: text.titleMedium),
          // A Row (not a lazy ListView) so the strip sizes to its tallest
          // item under any text scale; 24 items are cheap to build.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                for (final (i, h) in hours.indexed)
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: i == 0 ? context.colors.glass : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      spacing: 6,
                      children: [
                        Text(
                          i == 0 ? l10n.now : time.format(h.time),
                          style: text.labelMedium,
                          maxLines: 1,
                        ),
                        Icon(h.condition.icon(isDay: h.isDay), size: 22),
                        Text(
                          units.formatTemp(h.temperature),
                          style: text.bodyLarge,
                        ),
                        if (h.precipitationProbability > 0)
                          Text(
                            '${h.precipitationProbability}%',
                            style: text.labelMedium?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              // Rain % in `rainy` blue is 1.3–3.5:1 on the blue
                              // gradients; text stays onWeather.
                              color: context.colors.onWeather,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DailyCard extends ConsumerWidget {
  const DailyCard({super.key, required this.days, this.onDayTap});

  final List<DailyForecast> days;

  /// Opens Day Detail; null (e.g. in the skeleton) leaves rows inert.
  final ValueChanged<int>? onDayTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).units;
    final l10n = context.l10n;
    final text = context.textTheme;
    final colors = context.colors;
    final weekMin = days.map((d) => d.tempMin).fold(double.infinity, _min);
    final weekMax = days.map((d) => d.tempMax).fold(-double.infinity, _max);
    final muted = colors.onWeather.withValues(alpha: 0.7);
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.dailyTitle, style: text.titleMedium),
          ),
          for (final (i, d) in days.indexed) ...[
            Divider(color: colors.glass, height: 1),
            InkWell(
              onTap: onDayTap == null ? null : () => onDayTap!(i),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        i == 0
                            ? l10n.today
                            : l10n.weekdayShort('${d.date.weekday}'),
                        style: text.bodyMedium?.copyWith(
                          fontWeight: i == 0 ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    Icon(d.condition.icon(), size: 22),
                    SizedBox(
                      width: 32,
                      child: Text(
                        d.precipitationProbabilityMax > 0
                            ? '${d.precipitationProbabilityMax}%'
                            : '',
                        textAlign: TextAlign.right,
                        style: text.labelMedium?.copyWith(
                          fontSize: 11,
                          color: colors.onWeather,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        units.formatTemp(d.tempMin),
                        textAlign: TextAlign.right,
                        style: text.bodyMedium?.copyWith(color: muted),
                      ),
                    ),
                    Expanded(
                      child: _RangeBar(
                        start: _fraction(d.tempMin, weekMin, weekMax),
                        end: _fraction(d.tempMax, weekMin, weekMax),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        units.formatTemp(d.tempMax),
                        style: text.bodyMedium,
                      ),
                    ),
                    Icon(
                      Symbols.chevron_right_rounded,
                      size: 16,
                      color: colors.onWeather.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;

  static double _fraction(double t, double min, double max) =>
      max == min ? 0 : (t - min) / (max - min);
}

/// Shows one day's min–max inside the week's overall range.
class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.start, required this.end});

  final double start;
  final double end;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, box) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: colors.onWeather.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: box.maxWidth * start),
          width: box.maxWidth * (end - start),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.rainy, colors.sunny]),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class DetailGrid extends ConsumerWidget {
  const DetailGrid({super.key, required this.current, required this.today});

  final CurrentWeather current;
  final DailyForecast? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).units;
    final l10n = context.l10n;
    final text = context.textTheme;
    final c = current;
    final today = this.today;
    final time = DateFormat.Hm(Localizations.localeOf(context).toString());
    final km = c.visibility / 1000;
    Widget value(String v) => Text(v, style: text.titleLarge);
    final tiles = [
      _DetailTile(
        icon: Symbols.humidity_percentage_rounded,
        label: l10n.humidity,
        value: value('${c.humidity}%'),
        caption: l10n.dewPoint(units.formatTemp(c.dewPoint)),
      ),
      _DetailTile(
        icon: Symbols.navigation_rounded,
        iconAngle: c.windDirection,
        label: l10n.wind,
        value: value(units.formatWind(c.windSpeed)),
        caption: l10n.windFrom(c.windFrom.name),
      ),
      _DetailTile(
        icon: Symbols.light_mode_rounded,
        label: l10n.uvIndex,
        value: value('${c.uvIndex.round()}'),
        bar: (c.uvIndex / 11).clamp(0, 1),
        caption: l10n.uvLevel(c.uvLevel.name),
      ),
      _DetailTile(
        icon: Symbols.speed_rounded,
        label: l10n.pressure,
        value: value('${c.pressure.round()} hPa'),
      ),
      _DetailTile(
        icon: Symbols.visibility_rounded,
        label: l10n.visibility,
        value: value('${km >= 10 ? km.round() : km.toStringAsFixed(1)} km'),
      ),
      if (today != null)
        _DetailTile(
          icon: Symbols.wb_twilight_rounded,
          label: l10n.sunriseSunset,
          value: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              for (final (icon, t) in [
                (Symbols.wb_twilight_rounded, today.sunrise),
                (Symbols.bedtime_rounded, today.sunset),
              ])
                Row(
                  spacing: 6,
                  children: [
                    Icon(icon, size: 16),
                    Text(time.format(t), style: text.titleMedium),
                  ],
                ),
            ],
          ),
        ),
    ];
    return Column(
      spacing: 16,
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Expanded(child: tiles[i]),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconAngle = 0,
    this.bar,
    this.caption,
  });

  final IconData icon;
  final String label;
  final Widget value;

  /// Degrees clockwise, for the wind arrow.
  final int iconAngle;

  /// 0–1 fill of the UV scale bar.
  final double? bar;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colors;
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 6,
            children: [
              Transform.rotate(
                angle: iconAngle * math.pi / 180,
                child: Icon(icon, size: 20),
              ),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: text.labelMedium?.copyWith(letterSpacing: 0.36),
                ),
              ),
            ],
          ),
          value,
          if (bar != null)
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: colors.onWeather.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: bar,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.sunny,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          if (caption != null)
            Text(
              caption!,
              style: text.bodyMedium?.copyWith(
                color: colors.onWeather.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }
}

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
    return _GlassCard(
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
