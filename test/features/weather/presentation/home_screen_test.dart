import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/location/domain/entities/place.dart';
import 'package:weather_application/features/location/presentation/providers/location_provider.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/features/weather/domain/entities/weather.dart';
import 'package:weather_application/features/weather/presentation/providers/weather_provider.dart';
import 'package:weather_application/features/weather/presentation/screens/home_screen.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../data/weather_fixture.dart';

const _place = Place(lat: 21.03, lon: 105.85, name: 'Hà Nội');

Future<Widget> _app(List overrides, {AirQuality? airQuality}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    retry: noAutoRetry,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      airQualityProvider(
        _place.lat,
        _place.lon,
      ).overrideWith((ref) async => airQuality),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );
}

void main() {
  testWidgets('shows current weather, hourly and daily sections', (
    tester,
  ) async {
    final weather = WeatherDto.fromJson(weatherJson()).toEntity();
    await tester.pumpWidget(
      await _app([
        currentPlaceProvider.overrideWith((ref) async => _place),
        weatherProvider(
          _place.lat,
          _place.lon,
        ).overrideWith((ref) async => weather),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text('30°'), findsWidgets);
    expect(find.text('C:32° T:25°'), findsOneWidget);
    expect(find.text('Dự báo 24 giờ'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Bây giờ'), findsOneWidget);
  });

  testWidgets('air quality card shows the AQI and its level', (tester) async {
    final weather = WeatherDto.fromJson(weatherJson()).toEntity();
    await tester.pumpWidget(
      await _app([
        currentPlaceProvider.overrideWith((ref) async => _place),
        weatherProvider(
          _place.lat,
          _place.lon,
        ).overrideWith((ref) async => weather),
      ], airQuality: const AirQuality(usAqi: 174, pm25: 31.4, pm10: 32.4)),
    );
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('174'),
      300,
      // The PageView is also a Scrollable; pick the vertical page list.
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );

    expect(find.text('Xấu'), findsOneWidget);
    expect(find.text('PM2.5 31 µg/m³ · PM10 32 µg/m³'), findsOneWidget);
  });

  testWidgets('cached data shows the offline banner', (tester) async {
    final weather = WeatherDto.fromJson(weatherJson())
        .toEntity(cachedAt: DateTime.now().copyWith(hour: 8, minute: 15));
    await tester.pumpWidget(
      await _app([
        currentPlaceProvider.overrideWith((ref) async => _place),
        weatherProvider(
          _place.lat,
          _place.lon,
        ).overrideWith((ref) async => weather),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Đang offline · cập nhật lúc 8:15'), findsOneWidget);
  });

  testWidgets('location failure shows the error view with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _app([
        currentPlaceProvider.overrideWith(
          (ref) async => throw const LocationFailure(LocationError.denied),
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Cần quyền vị trí để hiển thị thời tiết nơi bạn ở'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
