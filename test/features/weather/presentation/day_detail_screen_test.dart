import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/router/app_router.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/location/domain/entities/place.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/features/weather/presentation/providers/weather_provider.dart';
import 'package:weather_application/features/weather/presentation/screens/day_detail_screen.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../data/weather_fixture.dart';

const _place = Place(lat: 21.03, lon: 105.85, name: 'Hà Nội');

void main() {
  test('Routes.dayOf encodes the place as query parameters', () {
    expect(
      Routes.dayOf(2, _place),
      '/day/2?lat=21.03&lon=105.85&name=H%C3%A0+N%E1%BB%99i',
    );
    expect(
      Routes.dayOf(0, const Place(lat: 1, lon: 2)),
      '/day/0?lat=1.0&lon=2.0',
    );
  });

  testWidgets('shows the chosen day and switches days via chips', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final weather = WeatherDto.fromJson(weatherJson()).toEntity();
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutoRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          weatherProvider(
            _place.lat,
            _place.lon,
          ).overrideWith((ref) async => weather),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DayDetailScreen(initialDay: 0, place: _place),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Thứ Năm, 24/09'), findsOneWidget);
    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text('25° – 32°'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('18 km/h'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hướng Đông Nam'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('25'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('25'));
    await tester.pump();
    expect(find.text('Thứ Sáu, 25/09'), findsOneWidget);
    expect(find.text('Dông'), findsOneWidget);
  });
}
