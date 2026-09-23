import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_ext.dart';
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
        loading: () => const AppLoading(),
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
          loading: () => const AppLoading(),
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
