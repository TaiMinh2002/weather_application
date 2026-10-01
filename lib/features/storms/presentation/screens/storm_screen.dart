import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../location/domain/entities/place.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/storm.dart';
import '../providers/storms_provider.dart';
import '../widgets/storm_card.dart';

/// Shapes the loading skeleton; never shown as data.
final _placeholder = Storm(
  id: '',
  name: 'Placeholder',
  issuedAt: DateTime.utc(2026),
  track: const [],
  points: [
    for (var i = 0; i < 4; i++)
      StormPoint(
        time: DateTime.utc(2026, 1, 1, i * 12),
        hoursAhead: i * 12,
        lat: 16,
        lon: 112,
        windMs: 25,
        gustMs: 33,
        pressure: 980,
      ),
  ],
);

/// Track map plus the forecast, time by time, for one storm.
class StormScreen extends ConsumerWidget {
  const StormScreen({super.key, required this.id, required this.place});

  final String id;

  /// Where distances are measured from, and the "you" marker.
  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final storms = ref.watch(activeStormsProvider);
    final storm = storms.value?.where((s) => s.id == id).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          storm == null ? l10n.stormWatch : stormTitle(l10n, storm, storm.now),
        ),
      ),
      body: storms.when(
        // The real layout over placeholder data, so nothing jumps when the
        // storm arrives. The map area stays plain: tiles aren't content.
        loading: () => Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: context.colorScheme.surfaceContainerHighest,
              ),
            ),
            Skeletonizer(
              child: _Timeline(storm: _placeholder, place: place),
            ),
          ],
        ),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(activeStormsProvider),
        ),
        data: (_) => storm == null
            ? EmptyView(icon: Symbols.cyclone_rounded, message: l10n.stormGone)
            : _StormBody(storm: storm, place: place),
      ),
    );
  }
}

class _StormBody extends StatelessWidget {
  const _StormBody({required this.storm, required this.place});

  final Storm storm;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final you = LatLng(place.lat, place.lon);
    final points = [for (final p in storm.points) LatLng(p.lat, p.lon)];
    final past = [for (final t in storm.track) LatLng(t.lat, t.lon)];
    return Column(
      children: [
        // A column, not an overlay: the OSM attribution in the map's corner
        // must stay visible (tile usage policy).
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(
                coordinates: [you, ...points],
                padding: const EdgeInsets.all(48),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // Required by the OSM tile usage policy.
                userAgentPackageName: 'com.example.weather_application',
              ),
              // Where the centre is 70% likely to be at each forecast time.
              CircleLayer(
                circles: [
                  for (final p in storm.points)
                    if (p.radiusKm case final r?)
                      CircleMarker(
                        point: LatLng(p.lat, p.lon),
                        radius: r * 1000,
                        useRadiusInMeter: true,
                        color: scheme.error.withValues(alpha: 0.12),
                        borderColor: scheme.error.withValues(alpha: 0.5),
                        borderStrokeWidth: 1,
                      ),
                ],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: past, color: scheme.error, strokeWidth: 3),
                  Polyline(
                    points: points,
                    color: scheme.error,
                    strokeWidth: 2,
                    pattern: StrokePattern.dashed(segments: const [8, 6]),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final (i, p) in points.indexed)
                    Marker(
                      point: p,
                      width: 28,
                      height: 28,
                      child: Icon(
                        Symbols.cyclone_rounded,
                        color: scheme.error,
                        size: i == 0 ? 28 : 18,
                      ),
                    ),
                  Marker(
                    point: you,
                    width: 28,
                    height: 28,
                    child: Icon(
                      Symbols.my_location_rounded,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              // Attribution is a licence requirement, so it isn't translated.
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                  TextSourceAttribution('Japan Meteorological Agency'),
                ],
              ),
            ],
          ),
        ),
        _Timeline(storm: storm, place: place),
      ],
    );
  }
}

/// Now and each forecast time: when, how strong, how far from the user.
class _Timeline extends ConsumerWidget {
  const _Timeline({required this.storm, required this.place});

  final Storm storm;
  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final muted = context.colors.textMuted;
    final units = ref.watch(settingsProvider.select((s) => s.units));
    final locale = Localizations.localeOf(context).toString();
    final when = DateFormat.E(locale).add_Hm();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          for (final p in storm.points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  SizedBox(
                    // Fits "Th 5 16:00" on one line.
                    width: 92,
                    child: Text(
                      p.hoursAhead == 0
                          ? l10n.now
                          : when.format(p.time.toLocal()),
                      style: text.labelLarge,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.isLow ? l10n.stormLow : stormTitle(l10n, storm, p),
                          style: text.bodyLarge,
                        ),
                        Text(
                          [
                            ?stormWind(l10n, units, p),
                            if (p.pressure case final hpa?) '$hpa hPa',
                            l10n.stormDistance(
                              distanceKm(
                                p.lat,
                                p.lon,
                                place.lat,
                                place.lon,
                              ).round(),
                            ),
                          ].join(' · '),
                          style: text.bodyMedium?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (storm.cachedAt case final cachedAt?)
            Text(
              context.offlineSince(cachedAt),
              style: text.labelMedium?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          Text(
            l10n.stormSource(
              DateFormat.MMMd(locale).add_Hm().format(storm.issuedAt.toLocal()),
            ),
            style: text.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
