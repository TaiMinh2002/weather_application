import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/utils/weather_code_mapper.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../location/domain/entities/place.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../domain/entities/weather.dart';
import '../providers/weather_provider.dart';

// ponytail: minimal view to prove the data layer; real Home UI is day 5–6.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(currentPlaceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(place.value?.name ?? context.l10n.appTitle)),
      body: place.when(
        data: (p) => _PlaceWeather(place: p),
        loading: () => const _HomeSkeleton(),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(currentPlaceProvider),
        ),
      ),
    );
  }
}

class _PlaceWeather extends ConsumerWidget {
  const _PlaceWeather({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = weatherProvider(place.lat, place.lon);
    return ref
        .watch(provider)
        .when(
          data: (w) => RefreshIndicator(
            onRefresh: () => ref.refresh(provider.future),
            child: _CurrentView(weather: w),
          ),
          loading: () => const _HomeSkeleton(),
          error: (e, _) =>
              AppErrorView(error: e, onRetry: () => ref.invalidate(provider)),
        );
  }
}

class _CurrentView extends StatelessWidget {
  const _CurrentView({required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final c = weather.current;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(c.condition.icon(isDay: c.isDay), size: 96),
        Text(
          '${c.temperature.round()}°',
          textAlign: TextAlign.center,
          style: context.textTheme.displayLarge,
        ),
        Text(
          c.condition.label(context.l10n),
          textAlign: TextAlign.center,
          style: context.textTheme.titleMedium,
        ),
        Text(
          context.l10n.feelsLike('${c.apparentTemperature.round()}°'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textMuted),
        ),
      ],
    );
  }
}

/// Renders the real layout with fake data so the skeleton matches it.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  static final _placeholder = Weather(
    current: CurrentWeather(
      time: DateTime(2000),
      temperature: 30,
      apparentTemperature: 30,
      humidity: 50,
      isDay: true,
      condition: WeatherCondition.partlyCloudy,
      windSpeed: 10,
      windDirection: 0,
      pressure: 1010,
      uvIndex: 5,
      visibility: 10000,
    ),
    hourly: const [],
    daily: const [],
  );

  @override
  Widget build(BuildContext context) =>
      Skeletonizer(child: _CurrentView(weather: _placeholder));
}
