import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../location/domain/entities/place.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../weather/presentation/providers/weather_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/city.dart';
import '../providers/cities_provider.dart';

/// Search and saved-city management in one screen: an empty query shows the
/// saved list, typing shows geocoding results.
///
/// Pops with the Home page to show: 0 for GPS, i + 1 for saved city i.
class CitiesScreen extends ConsumerStatefulWidget {
  const CitiesScreen({super.key});

  @override
  ConsumerState<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends ConsumerState<CitiesScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Open-Meteo geocoding needs at least 2 characters to match anything.
    final searching = _query.length >= 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cities),
        actions: [
          IconButton(
            tooltip: l10n.pickOnMap,
            icon: const Icon(Symbols.map_rounded),
            onPressed: () async {
              final city = await context.push<City>(Routes.map);
              if (city != null && context.mounted) {
                await _saveAndShow(context, ref, city);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchCityHint,
                prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clear,
                        tooltip: l10n.clearSearch,
                        icon: const Icon(Symbols.close_rounded, size: 20),
                      ),
              ),
            ),
          ),
          Expanded(
            child: searching
                ? _SearchResults(query: _query)
                : const _SavedList(),
          ),
        ],
      ),
    );
  }
}

/// Saves [city] (a search result or a map pick) and returns to Home on its
/// page.
Future<void> _saveAndShow(
  BuildContext context,
  WidgetRef ref,
  City city,
) async {
  await ref.read(savedCitiesProvider.notifier).add(city);
  final index = ref
      .read(savedCitiesProvider)
      .indexWhere((c) => c.id == city.id);
  if (context.mounted) context.pop(index + 1);
}

class _SavedList extends ConsumerWidget {
  const _SavedList();

  void _delete(BuildContext context, WidgetRef ref, int index, City city) {
    final notifier = ref.read(savedCitiesProvider.notifier);
    notifier.remove(city);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.cityDeleted(city.name)),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () => notifier.insert(index, city),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cities = ref.watch(savedCitiesProvider);
    // No GPS row while location is denied; Home explains why.
    final gps = ref.watch(currentPlaceProvider).value;
    final gpsRow = gps == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CityRow(
              leading: Icon(
                Symbols.my_location_rounded,
                size: 20,
                color: context.colorScheme.primary,
              ),
              title: l10n.currentLocation,
              subtitle: gps.name,
              place: gps,
              onTap: () => context.pop(0),
            ),
          );

    if (cities.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ?gpsRow,
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: EmptyView(
              icon: Symbols.location_city_rounded,
              message: l10n.savedCitiesEmpty,
              hint: l10n.savedCitiesEmptyHint,
            ),
          ),
        ],
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      // Long-press anywhere on a row drags it, as the footnote says; the
      // handle icon is only a visual cue.
      buildDefaultDragHandles: false,
      header: gpsRow,
      footer: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          l10n.savedCitiesHint,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colors.textMuted,
          ),
        ),
      ),
      proxyDecorator: (child, _, _) => Material(
        color: context.colorScheme.surfaceContainer,
        elevation: 8,
        shadowColor: context.colorScheme.shadow.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemCount: cities.length,
      onReorderItem: (from, to) =>
          ref.read(savedCitiesProvider.notifier).move(from, to),
      itemBuilder: (context, i) {
        final city = cities[i];
        return Padding(
          key: ValueKey(city.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ObjectKey(city),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _delete(context, ref, i, city),
            background: const _DeleteBackground(),
            child: ReorderableDelayedDragStartListener(
              index: i,
              child: _CityRow(
                leading: Icon(
                  Symbols.drag_handle_rounded,
                  size: 20,
                  color: context.colors.textMuted,
                ),
                title: city.name,
                subtitle: city.country,
                place: city.place,
                onTap: () => context.pop(i + 1),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(
            context.l10n.delete,
            style: context.textTheme.labelLarge?.copyWith(
              color: scheme.onError,
            ),
          ),
          Icon(Symbols.delete_rounded, size: 20, color: scheme.onError),
        ],
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.place,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Material(
      color: context.colors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            spacing: 12,
            children: [
              leading,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.bodyLarge),
                    if (subtitle case final subtitle?)
                      Text(
                        subtitle,
                        style: text.bodyMedium?.copyWith(
                          color: context.colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              _CurrentTemp(place: place),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reuses Home's weather provider, so a city Home already loaded shows
/// instantly.
class _CurrentTemp extends ConsumerWidget {
  const _CurrentTemp({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = context.textTheme.titleLarge;
    final units = ref.watch(settingsProvider).units;
    return ref
        .watch(weatherProvider(place.lat, place.lon))
        .when(
          data: (w) =>
              Text(units.formatTemp(w.current.temperature), style: style),
          loading: () =>
              Skeletonizer(child: Text(units.formatTemp(30), style: style)),
          // The row stays useful without a temperature; Home shows the error.
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = {for (final c in ref.watch(savedCitiesProvider)) c.id};
    final provider = citySearchProvider(query);
    return ref
        .watch(provider)
        .when(
          data: (results) => results.isEmpty
              ? EmptyView(
                  icon: Symbols.search_off_rounded,
                  message: context.l10n.searchNoResults(query),
                )
              : _ResultList(
                  results: results,
                  savedIds: savedIds,
                  onSelect: (city) => _saveAndShow(context, ref, city),
                ),
          loading: () => Skeletonizer(
            child: _ResultList(
              results: [
                for (var i = 0; i < 4; i++)
                  City(
                    id: i,
                    name: context.l10n.searchCityHint,
                    lat: 0,
                    lon: 0,
                    country: context.l10n.currentLocation,
                  ),
              ],
              savedIds: const {},
              onSelect: (_) {},
            ),
          ),
          error: (e, _) =>
              AppErrorView(error: e, onRetry: () => ref.invalidate(provider)),
        );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.results,
    required this.savedIds,
    required this.onSelect,
  });

  final List<City> results;
  final Set<int> savedIds;
  final ValueChanged<City> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: results.length,
      itemBuilder: (context, i) {
        final city = results[i];
        return InkWell(
          onTap: () => onSelect(city),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(city.name, style: text.bodyLarge),
                      if (city.area.isNotEmpty)
                        Text(
                          city.area,
                          style: text.bodyMedium?.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (savedIds.contains(city.id))
                  Icon(
                    Symbols.check_rounded,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
