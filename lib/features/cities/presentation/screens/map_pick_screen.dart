import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../weather/presentation/providers/weather_provider.dart';
import '../../domain/entities/city.dart';

/// Tap anywhere to preview its weather, then save it as a city.
/// Pops with the chosen [City]; Cities saves it and returns to Home.
class MapPickScreen extends ConsumerStatefulWidget {
  const MapPickScreen({super.key});

  @override
  ConsumerState<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends ConsumerState<MapPickScreen> {
  /// Centre of Vietnam, for when GPS isn't available.
  static const _fallbackCenter = LatLng(16, 106);

  LatLng? _picked;

  @override
  Widget build(BuildContext context) {
    final gps = ref.watch(currentPlaceProvider).value;
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pickOnMap)),
      // A column, not an overlay: the OSM attribution in the map's corner
      // must stay visible (tile usage policy).
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: gps == null
                    ? _fallbackCenter
                    : LatLng(gps.lat, gps.lon),
                initialZoom: gps == null ? 5 : 9,
                onTap: (_, point) => setState(() => _picked = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Required by the OSM tile usage policy.
                  userAgentPackageName: 'com.example.weather_application',
                ),
                if (picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: picked,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Symbols.location_on_rounded,
                          fill: 1,
                          size: 40,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                // Attribution is a licence requirement, so it isn't translated.
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: picked == null
                ? const _HintCard()
                : _PickedCard(
                    key: ValueKey(picked),
                    lat: picked.latitude,
                    lon: picked.longitude,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colorScheme.surfaceContainer,
    elevation: 3,
    borderRadius: BorderRadius.circular(20),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      spacing: 12,
      children: [
        Icon(Symbols.touch_app_rounded, color: context.colors.textMuted),
        Expanded(
          child: Text(context.l10n.mapHint, style: context.textTheme.bodyLarge),
        ),
      ],
    ),
  );
}

class _PickedCard extends ConsumerWidget {
  const _PickedCard({super.key, required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.textTheme;
    final coords = '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
    final place = ref.watch(placeAtProvider(lat, lon));
    final units = ref.watch(settingsProvider).units;
    final weather = ref.watch(weatherProvider(lat, lon));
    final resolved = place.value;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Skeletonizer(
                  enabled: place.isLoading,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resolved?.name ?? coords, style: text.titleMedium),
                      Text(
                        coords,
                        style: text.bodyMedium?.copyWith(
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Weather is a preview: loading shows a bone, a failure shows
              // nothing, and saving works either way.
              switch (weather) {
                AsyncData(:final value) => Row(
                  spacing: 6,
                  children: [
                    Icon(
                      value.current.condition.icon(isDay: value.current.isDay),
                    ),
                    Text(
                      units.formatTemp(value.current.temperature),
                      style: text.titleLarge,
                    ),
                  ],
                ),
                AsyncLoading() => Skeletonizer(
                  child: Text(units.formatTemp(30), style: text.titleLarge),
                ),
                _ => const SizedBox.shrink(),
              },
            ],
          ),
          FilledButton(
            onPressed: resolved == null
                ? null
                : () => context.pop(
                    City.fromPlace(resolved, fallbackName: coords),
                  ),
            child: Text(context.l10n.saveCity),
          ),
        ],
      ),
    );
  }
}
