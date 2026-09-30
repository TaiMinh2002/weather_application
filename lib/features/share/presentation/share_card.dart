import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/error/errors.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../../activities/domain/activity.dart';
import '../../activities/presentation/activities_card.dart';
import '../../location/domain/entities/place.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../weather/domain/entities/weather.dart';
import '../../weather/presentation/providers/weather_provider.dart';
import '../../weather/presentation/widgets/insight_cards.dart';

/// Previews the share image, then hands it to the system share sheet.
Future<void> showShareCard(
  BuildContext context, {
  required Weather weather,
  required Place place,
  required String name,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ShareSheet(weather: weather, place: place, name: name),
);

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({
    required this.weather,
    required this.place,
    required this.name,
  });

  final Weather weather;
  final Place place;
  final String name;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _card = GlobalKey();
  final _button = GlobalKey();
  var _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    // iPad anchors the share popover to this rect; phones ignore it.
    final button = _button.currentContext!.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero) & button.size;
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // ShareCard lays out at a fixed logical size, so this is always
    // 1080×1920, the story size social apps expect.
    final image = await boundary.toImage(
      pixelRatio: 1080 / ShareCard.size.width,
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await runQuietly(
      () => SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: const ['skycast.png'],
          // Image only: Messenger, Facebook and Instagram hide themselves
          // from the share sheet when text comes along with it.
          sharePositionOrigin: origin,
        ),
      ),
    );
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final air = ref.watch(airQualityProvider(place.lat, place.lon)).value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            // The card is laid out at its own fixed size and only scaled to
            // fit here, so the exported image never depends on the phone.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: RepaintBoundary(
                    key: _card,
                    child: ShareCard(
                      weather: widget.weather,
                      name: widget.name,
                      air: air,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: _button,
                onPressed: _sharing ? null : _share,
                icon: const Icon(Symbols.ios_share_rounded, size: 20),
                label: Text(context.l10n.share),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The image itself, story-sized (9:16): a one-glance brief of today, not
/// just the temperature. Square corners, because transparent rounded ones
/// turn into white or black notches in most chat apps.
class ShareCard extends ConsumerWidget {
  const ShareCard({
    super.key,
    required this.weather,
    required this.name,
    this.air,
  });

  /// Logical size; exported at 3× (1080×1920).
  static const size = Size(360, 640);

  final Weather weather;
  final String name;
  final AirQuality? air;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final onWeather = context.colors.onWeather;
    final settings = ref.watch(settingsProvider);
    final units = settings.units;
    final locale = Localizations.localeOf(context).toString();
    final c = weather.current;
    final today = weather.daily.firstOrNull;
    final air = this.air;

    // The one sentence worth reading first: rain about to start beats the
    // general advice.
    final (IconData, String) headline = switch (rainOutlook(weather.nowcast)) {
      final r? => (
        Symbols.rainy_rounded,
        l10n.rainOutlook(r.trend.name, r.minutes),
      ),
      null => switch (tipsFor(weather, air, max: 1).first) {
        final tip => (TipsCard.iconFor(tip), l10n.weatherTip(tip.name)),
      },
    };

    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: weatherGradient(c.condition, isDay: c.isDay),
        ),
        child: IconTheme(
          data: IconThemeData(color: onWeather),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: onWeather),
            child: Stack(
              children: [
                // A soft glow behind the weather icon, so the top doesn't
                // read as a flat slab of colour.
                Positioned(
                  top: -70,
                  right: -70,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          onWeather.withValues(alpha: 0.28),
                          onWeather.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          const Icon(
                            Symbols.partly_cloudy_day_rounded,
                            size: 18,
                          ),
                          Text(
                            'Skycast',
                            style: text.labelLarge?.copyWith(
                              color: onWeather,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          // Long dates ("Wednesday, September 30") shrink
                          // with an ellipsis instead of overflowing.
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _Muted(
                                DateFormat.MMMMEEEEd(locale).format(c.time),
                                style: text.labelMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: text.headlineSmall?.copyWith(
                          color: onWeather,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  units.formatTemp(c.temperature),
                                  style: text.displayLarge?.copyWith(
                                    color: onWeather,
                                    fontSize: 76,
                                    height: 1.05,
                                  ),
                                ),
                                Text(
                                  c.condition.label(l10n),
                                  style: text.titleMedium?.copyWith(
                                    color: onWeather,
                                  ),
                                ),
                                _Muted(
                                  [
                                    if (today != null)
                                      l10n.hiLo(
                                        units.formatTemp(today.tempMax),
                                        units.formatTemp(today.tempMin),
                                      ),
                                    l10n.feelsLike(
                                      units.formatTemp(c.apparentTemperature),
                                    ),
                                  ].join(' · '),
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(c.condition.icon(isDay: c.isDay), size: 84),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Glass(
                        child: Row(
                          spacing: 10,
                          children: [
                            Icon(headline.$1, size: 20),
                            Expanded(
                              child: Text(
                                headline.$2,
                                style: text.bodyMedium?.copyWith(
                                  color: onWeather,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Same height for every tile, with or without a level.
                      IntrinsicHeight(
                        child: Row(
                          spacing: 8,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Stat(
                              icon: Symbols.umbrella_rounded,
                              label: l10n.shareRain,
                              value:
                                  '${today?.precipitationProbabilityMax ?? 0}%',
                            ),
                            _Stat(
                              icon: Symbols.light_mode_rounded,
                              label: l10n.uvIndex,
                              value:
                                  '${(today?.uvIndexMax ?? c.uvIndex).round()}',
                              sub: l10n.uvLevel(
                                (today?.uvLevel ?? c.uvLevel).name,
                              ),
                            ),
                            if (air != null)
                              _Stat(
                                icon: Symbols.airwave_rounded,
                                label: 'AQI',
                                value: '${air.usAqi}',
                                sub: l10n.aqiLevel(air.level.name),
                              ),
                            _Stat(
                              icon: Symbols.air_rounded,
                              label: l10n.wind,
                              value: units.formatWind(c.windSpeed),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Hourly(hours: weather.next24Hours),
                      const SizedBox(height: 10),
                      if (settings.activities.isNotEmpty)
                        _Activities(
                          weather: weather,
                          air: air,
                          activities: [
                            ...Activity.values.where(
                              settings.activities.contains,
                            ),
                          ].take(3).toList(),
                        ),
                      const Spacer(),
                      // Open-Meteo's licence (CC BY 4.0) asks for attribution.
                      Center(
                        child: _Muted(
                          'Skycast · Open-Meteo',
                          style: text.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: style?.copyWith(
      color: context.colors.onWeather.withValues(alpha: 0.8),
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.colors.glass,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Expanded(
      child: _Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Row(
              spacing: 4,
              children: [
                Icon(icon, size: 14),
                Flexible(child: _Muted(label, style: text.labelSmall)),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: text.titleMedium?.copyWith(
                  color: context.colors.onWeather,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (sub case final sub?)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _Muted(sub, style: text.labelSmall),
              ),
          ],
        ),
      ),
    );
  }
}

/// Every other hour over the next 12, so six columns fit the width.
class _Hourly extends ConsumerWidget {
  const _Hourly({required this.hours});

  final List<HourlyForecast> hours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final units = ref.watch(settingsProvider).units;
    final hm = DateFormat.Hm(Localizations.localeOf(context).toString());
    final picked = [
      for (var i = 0; i < hours.length && i < 12; i += 2) hours[i],
    ];
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          _Muted(l10n.shareNext12h.toUpperCase(), style: text.labelSmall),
          Row(
            children: [
              for (final (i, h) in picked.indexed)
                Expanded(
                  child: Column(
                    spacing: 2,
                    children: [
                      _Muted(
                        i == 0 ? l10n.now : hm.format(h.time),
                        style: text.labelSmall,
                      ),
                      Icon(h.condition.icon(isDay: h.isDay), size: 20),
                      Text(
                        units.formatTemp(h.temperature),
                        style: text.labelLarge?.copyWith(
                          color: context.colors.onWeather,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _Muted(
                        '${h.precipitationProbability}%',
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Best time left today for each picked activity (up to three).
class _Activities extends StatelessWidget {
  const _Activities({
    required this.weather,
    required this.air,
    required this.activities,
  });

  final Weather weather;
  final AirQuality? air;
  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final hm = DateFormat.Hm(Localizations.localeOf(context).toString());
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          _Muted(l10n.activitiesTitle.toUpperCase(), style: text.labelSmall),
          for (final a in activities)
            if (bestWindow(
                  a,
                  weather.hourly,
                  from: weather.current.time,
                  air: air,
                )
                case final w)
              Row(
                spacing: 10,
                children: [
                  Icon(activityIcon(a), size: 18),
                  Expanded(
                    child: Text(
                      l10n.activityName(a.name),
                      style: text.bodyMedium?.copyWith(
                        color: context.colors.onWeather,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Shrinks (with an ellipsis) before the row can overflow,
                  // e.g. "No good time" next to a long activity name.
                  Flexible(
                    child: _Muted(
                      w == null ||
                              ActivityLevel.fromScore(w.score) ==
                                  ActivityLevel.poor
                          ? l10n.activityNoGoodTime
                          : '${hm.format(w.from)}–${hm.format(w.to)}',
                      style: text.labelMedium,
                    ),
                  ),
                  // Fixed width so the time column lines up across rows.
                  SizedBox(
                    width: 64,
                    child: Text(
                      l10n.activityLevel(
                        ActivityLevel.fromScore(w?.score ?? 0).name,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: text.labelMedium?.copyWith(
                        color: context.colors.onWeather,
                        fontWeight: FontWeight.w700,
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
