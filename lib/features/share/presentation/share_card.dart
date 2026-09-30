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
import '../../location/domain/entities/place.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../weather/domain/entities/weather.dart';
import '../../weather/presentation/providers/weather_provider.dart';

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
    final text = context.l10n.shareText(widget.name);
    // iPad anchors the share popover to this rect; phones ignore it.
    final button = _button.currentContext!.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero) & button.size;
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // 1080 px wide whatever the screen, the size social apps expect.
    final image = await boundary.toImage(
      pixelRatio: 1080 / boundary.size.width,
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
          text: text,
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
            // Fixed width so the image looks the same from any phone.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: RepaintBoundary(
                key: _card,
                child: ShareCard(
                  weather: widget.weather,
                  name: widget.name,
                  air: air,
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

/// The image itself, 4:5 like a social post: today's weather plus the one or
/// two things Skycast adds (rain soon, best time for the user's activity).
class ShareCard extends ConsumerWidget {
  const ShareCard({
    super.key,
    required this.weather,
    required this.name,
    this.air,
  });

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
    final hm = DateFormat.Hm(locale);
    final c = weather.current;
    final today = weather.daily.firstOrNull;

    final highlights = <(IconData, String)>[
      if (rainOutlook(weather.nowcast) case final r?)
        (Symbols.rainy_rounded, l10n.rainOutlook(r.trend.name, r.minutes)),
      for (final a in Activity.values.where(settings.activities.contains))
        if (bestWindow(a, weather.hourly, from: c.time, air: air) case final w?
            when w.score >= 60)
          (
            Symbols.event_available_rounded,
            l10n.morningActivity(
              l10n.activityName(a.name),
              '${hm.format(w.from)}–${hm.format(w.to)}',
            ),
          ),
    ].take(2);

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: weatherGradient(c.condition, isDay: c.isDay),
          borderRadius: BorderRadius.circular(28),
        ),
        child: IconTheme(
          data: IconThemeData(color: onWeather),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: onWeather),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: text.titleLarge?.copyWith(color: onWeather),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Opacity(
                  opacity: 0.8,
                  child: Text(
                    DateFormat.MMMMEEEEd(locale).format(c.time),
                    style: text.bodyMedium?.copyWith(color: onWeather),
                  ),
                ),
                const Spacer(),
                Row(
                  spacing: 12,
                  children: [
                    Icon(c.condition.icon(isDay: c.isDay), size: 56),
                    Text(
                      units.formatTemp(c.temperature),
                      style: text.displayLarge?.copyWith(
                        color: onWeather,
                        fontSize: 72,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  c.condition.label(l10n),
                  style: text.titleMedium?.copyWith(color: onWeather),
                ),
                Opacity(
                  opacity: 0.85,
                  child: Text(
                    [
                      if (today != null)
                        l10n.hiLo(
                          units.formatTemp(today.tempMax),
                          units.formatTemp(today.tempMin),
                        ),
                      l10n.feelsLike(units.formatTemp(c.apparentTemperature)),
                    ].join(' · '),
                    style: text.bodyMedium?.copyWith(color: onWeather),
                  ),
                ),
                const Spacer(),
                for (final (icon, line) in highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(icon, size: 18),
                        Expanded(
                          child: Text(
                            line,
                            style: text.bodyMedium?.copyWith(color: onWeather),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // Open-Meteo's licence (CC BY 4.0) asks for attribution.
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    'Skycast · Open-Meteo',
                    style: text.labelMedium?.copyWith(color: onWeather),
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
