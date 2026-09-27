import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/location/domain/entities/place.dart';
import 'package:weather_application/features/location/presentation/providers/location_provider.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/features/weather/presentation/providers/weather_provider.dart';
import 'package:weather_application/features/weather/presentation/screens/home_screen.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../data/weather_fixture.dart';

const _place = Place(lat: 21.03, lon: 105.85, name: 'Hà Nội');

Widget _app(List overrides) => ProviderScope(
  retry: noAutoRetry,
  overrides: [...overrides],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HomeScreen(),
  ),
);

void main() {
  testWidgets('shows current weather, hourly and daily sections', (
    tester,
  ) async {
    final weather = WeatherDto.fromJson(weatherJson()).toEntity();
    await tester.pumpWidget(
      _app([
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

  testWidgets('location failure shows the error view with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
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
