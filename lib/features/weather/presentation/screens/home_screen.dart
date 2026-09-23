import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/weather.dart';
import '../providers/weather_provider.dart';

// ponytail: fixed Hanoi coords until the location feature (plan.md day 4).
const _lat = 21.03;
const _lon = 105.85;

// ponytail: minimal view to prove the data layer; real Home UI is day 5–6.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = weatherProvider(_lat, _lon);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appTitle)),
      body: ref
          .watch(provider)
          .when(
            data: (w) => RefreshIndicator(
              onRefresh: () => ref.refresh(provider.future),
              child: _CurrentView(weather: w),
            ),
            loading: () => const AppLoading(),
            error: (e, _) =>
                AppErrorView(error: e, onRetry: () => ref.invalidate(provider)),
          ),
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
