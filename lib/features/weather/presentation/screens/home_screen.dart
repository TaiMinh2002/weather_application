import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/weather_code_mapper.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../cities/presentation/providers/cities_provider.dart';
import '../../../location/domain/entities/place.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/weather.dart';
import '../providers/weather_provider.dart';
import '../widgets/forecast_cards.dart';

/// Page 0 is the GPS location, then one page per saved city.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Cities returns the page to show: 0 for GPS, i + 1 for saved city i.
  Future<void> _openCities() async {
    final page = await context.push<int>(Routes.cities);
    if (page == null) return;
    // The saved list may have just grown; jump once the new page is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients) _pages.jumpToPage(page);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(savedCitiesProvider);
    final count = cities.length + 1;
    Widget topBar(int page) =>
        _TopBar(pageIndex: page, pageCount: count, onCities: _openCities);
    return Scaffold(
      body: PageView(
        controller: _pages,
        children: [
          _GpsPage(topBar: topBar(0), onChooseCity: _openCities),
          for (final (i, city) in cities.indexed)
            _PlaceWeather(
              key: ValueKey(city.id),
              place: city.place,
              topBar: topBar(i + 1),
            ),
        ],
      ),
    );
  }
}

class _GpsPage extends ConsumerWidget {
  const _GpsPage({required this.topBar, required this.onChooseCity});

  final Widget topBar;
  final VoidCallback onChooseCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(currentPlaceProvider)
      .when(
        data: (place) =>
            _PlaceWeather(place: place, topBar: topBar, isGps: true),
        loading: () => _GradientPage(
          gradient: loadingGradient,
          topBar: topBar,
          child: const _WeatherSkeleton(),
        ),
        error: (e, _) => _SurfacePage(
          topBar: topBar,
          child: AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(currentPlaceProvider),
            extraAction: TextButton(
              onPressed: onChooseCity,
              child: Text(context.l10n.chooseCity),
            ),
          ),
        ),
      );
}

class _PlaceWeather extends ConsumerWidget {
  const _PlaceWeather({
    super.key,
    required this.place,
    required this.topBar,
    this.isGps = false,
  });

  final Place place;
  final Widget topBar;
  final bool isGps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = weatherProvider(place.lat, place.lon);
    return ref
        .watch(provider)
        .when(
          data: (weather) => _GradientPage(
            gradient: weatherGradient(
              weather.current.condition,
              isDay: weather.current.isDay,
            ),
            topBar: topBar,
            child: Builder(
              builder: (context) => RefreshIndicator(
                onRefresh: () => ref.refresh(provider.future),
                color: context.colors.onWeather,
                backgroundColor: context.colors.glass,
                elevation: 0,
                child: _WeatherBody(
                  name: place.name ?? context.l10n.currentLocation,
                  showPin: isGps,
                  onDayTap: (i) => context.push(Routes.dayOf(i, place)),
                  weather: weather,
                ),
              ),
            ),
          ),
          loading: () => _GradientPage(
            gradient: loadingGradient,
            topBar: topBar,
            child: const _WeatherSkeleton(),
          ),
          error: (e, _) => _SurfacePage(
            topBar: topBar,
            child: AppErrorView(
              error: e,
              onRetry: () => ref.invalidate(provider),
            ),
          ),
        );
  }
}

/// Weather content sits on a gradient, so text and icons switch to
/// `onWeather` for the whole subtree instead of per widget.
///
/// Loading and loaded states both build this at the same spot, so the
/// gradient animates from [loadingGradient] to the weather's own, and again
/// when a refresh changes the condition or day/night.
class _GradientPage extends StatelessWidget {
  const _GradientPage({
    required this.gradient,
    required this.topBar,
    required this.child,
  });

  final Gradient gradient;
  final Widget topBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onWeather = context.colors.onWeather;
    final theme = context.theme;
    // Respect the OS "reduce motion" setting.
    final still = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: AnimatedContainer(
        duration: still ? Duration.zero : const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(gradient: gradient),
        child: Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.apply(
              bodyColor: onWeather,
              displayColor: onWeather,
            ),
            iconTheme: theme.iconTheme.copyWith(color: onWeather),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                topBar,
                Expanded(
                  child: AnimatedSwitcher(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    child: child,
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

class _SurfacePage extends StatelessWidget {
  const _SurfacePage({required this.topBar, required this.child});

  final Widget topBar;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion(
    value: context.theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    child: SafeArea(
      child: Column(
        children: [
          topBar,
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pageIndex,
    required this.pageCount,
    required this.onCities,
  });

  final int pageIndex;
  final int pageCount;
  final VoidCallback onCities;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? context.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onCities,
            color: color,
            tooltip: context.l10n.cities,
            icon: const Icon(Symbols.list_rounded),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: [
                for (var i = 0; i < pageCount; i++)
                  Opacity(
                    opacity: i == pageIndex ? 1 : 0.4,
                    // The GPS page is marked with an arrow instead of a dot.
                    child: i == 0
                        ? Icon(
                            Symbols.navigation_rounded,
                            size: 13,
                            color: color,
                          )
                        : Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(Routes.settings),
            color: color,
            tooltip: context.l10n.settings,
            icon: const Icon(Symbols.settings_rounded),
          ),
        ],
      ),
    );
  }
}

/// Renders the real layout with placeholder data, so the skeleton always
/// matches the loaded screen.
class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) => Skeletonizer(
    effect: ShimmerEffect(
      baseColor: context.colors.glass,
      highlightColor: context.colors.onWeather.withValues(alpha: 0.24),
      duration: const Duration(milliseconds: 1600),
    ),
    child: _WeatherBody(
      name: context.l10n.currentLocation,
      weather: _placeholderWeather(),
    ),
  );
}

Weather _placeholderWeather() {
  final now = DateTime.now();
  const condition = WeatherCondition.partlyCloudy;
  return Weather(
    current: CurrentWeather(
      time: now,
      temperature: 30,
      apparentTemperature: 32,
      humidity: 70,
      dewPoint: 24,
      isDay: true,
      condition: condition,
      windSpeed: 10,
      windDirection: 135,
      pressure: 1010,
      uvIndex: 5,
      visibility: 10000,
    ),
    hourly: [
      for (var h = 0; h < 24; h++)
        HourlyForecast(
          time: now.add(Duration(hours: h)),
          temperature: 30,
          condition: condition,
          precipitationProbability: 0,
          isDay: true,
        ),
    ],
    daily: [
      for (var d = 0; d < 7; d++)
        DailyForecast(
          date: now.add(Duration(days: d)),
          condition: condition,
          tempMax: 33,
          tempMin: 25,
          sunrise: now,
          sunset: now,
          uvIndexMax: 5,
          precipitationProbabilityMax: 0,
          windSpeedMax: 10,
          windDirectionDominant: 135,
        ),
    ],
  );
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({
    required this.name,
    required this.weather,
    this.showPin = true,
    this.onDayTap,
  });

  final String name;
  final bool showPin;
  final ValueChanged<int>? onDayTap;
  final Weather weather;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(
      16,
      14,
      16,
      40 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      if (weather.cachedAt case final cachedAt?) ...[
        _OfflineBanner(cachedAt: cachedAt),
        const SizedBox(height: 20),
      ],
      _Header(name: name, weather: weather, showPin: showPin),
      const SizedBox(height: 20),
      HourlyCard(hours: weather.next24Hours),
      const SizedBox(height: 20),
      DailyCard(days: weather.daily, onDayTap: onDayTap),
      const SizedBox(height: 20),
      DetailGrid(current: weather.current, today: weather.daily.firstOrNull),
    ],
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.cachedAt});

  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final sameDay = DateUtils.isSameDay(cachedAt, now);
    final time =
        (sameDay ? DateFormat.Hm(locale) : DateFormat.Md(locale).add_Hm())
            .format(cachedAt);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.glass,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        spacing: 8,
        children: [
          const Icon(Symbols.wifi_off_rounded, size: 18),
          Expanded(
            child: Text(
              context.l10n.offlineUpdatedAt(time),
              style: context.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.name,
    required this.weather,
    required this.showPin,
  });

  final String name;
  final bool showPin;
  final Weather weather;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).units;
    final l10n = context.l10n;
    final text = context.textTheme;
    final c = weather.current;
    final today = weather.daily.firstOrNull;
    // iPhone SE-sized screens: shrink the temperature so the hourly strip
    // still peeks above the fold.
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Column(
      spacing: 2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (showPin) const Icon(Symbols.location_on_rounded, size: 20),
            Flexible(
              child: Text(
                name,
                style: text.headlineMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            units.formatTemp(c.temperature),
            style: text.displayLarge?.copyWith(
              fontSize: compact ? 80 : null,
              height: 1,
            ),
          ),
        ),
        Text(c.condition.label(l10n), style: text.bodyLarge),
        if (today != null)
          Text(
            l10n.hiLo(
              units.formatTemp(today.tempMax),
              units.formatTemp(today.tempMin),
            ),
            style: text.bodyMedium,
          ),
        Opacity(
          opacity: 0.85,
          child: Text(
            l10n.feelsLike(units.formatTemp(c.apparentTemperature)),
            style: text.bodyMedium,
          ),
        ),
      ],
    );
  }
}
