import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/location/domain/entities/place.dart';
import 'package:weather_application/features/location/presentation/providers/location_provider.dart';
import 'package:weather_application/features/share/presentation/share_card.dart';
import 'package:weather_application/features/storms/presentation/providers/storms_provider.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/features/weather/domain/entities/weather.dart';
import 'package:weather_application/features/weather/presentation/providers/weather_provider.dart';
import 'package:weather_application/features/weather/presentation/screens/home_screen.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../data/weather_fixture.dart';

const _place = Place(lat: 21.03, lon: 105.85, name: 'Hà Nội');

// The PageView is also a Scrollable; this is the vertical page list.
final _pageList = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

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
      activeStormsProvider.overrideWith((ref) async => const []),
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
    expect(find.text('Bây giờ'), findsOneWidget);
    // Fixture: steady light rain and 33° feels-like, so only running is
    // borderline.
    expect(find.text('Chạy bộ'), findsOneWidget);
    expect(find.text('10:00–11:00'), findsOneWidget);
    expect(find.text('Tạm được'), findsOneWidget);
    expect(find.text('Không nên'), findsNWidgets(2));
    // The tips and daily cards sit below the 800×600 test viewport.
    await tester.scrollUntilVisible(
      find.text('Trời nóng, uống đủ nước và tránh nắng gắt'),
      200,
      scrollable: _pageList,
    );
    expect(
      find.text('UV cao, bôi kem chống nắng khi ra ngoài'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Hôm nay'),
      200,
      scrollable: _pageList,
    );
  });

  testWidgets('the share button opens the card preview', (tester) async {
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

    await tester.tap(find.byTooltip('Chia sẻ'));
    await tester.pumpAndSettle();

    expect(find.byType(ShareCard), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Chia sẻ'), findsOneWidget);
  });

  testWidgets('the activities sheet adds and removes rows', (tester) async {
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

    await tester.tap(find.byTooltip('Chọn hoạt động'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Đạp xe'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Chạy bộ'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(FilterChip).first)).pop();
    await tester.pumpAndSettle();

    expect(find.text('Đạp xe'), findsOneWidget);
    expect(find.text('Chạy bộ'), findsNothing);
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
    // Air quality starts loading only once the forecast has rendered.
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Không khí kém, nên đeo khẩu trang'),
      200,
      scrollable: _pageList,
    );
    await tester.scrollUntilVisible(
      find.text('174'),
      300,
      scrollable: _pageList,
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

  testWidgets('rain soon shows the nowcast card, but not offline', (
    tester,
  ) async {
    final json = weatherJson()
      ..['minutely_15'] = {
        'time': [for (var m = 15; m < 60; m += 15) '2026-09-24T10:$m'],
        'precipitation': [0.0, 0.0, 0.6],
      };
    for (final cachedAt in [null, DateTime(2026, 9, 24, 8)]) {
      final weather = WeatherDto.fromJson(json).toEntity(cachedAt: cachedAt);
      // A fresh tree, or the second pump would keep the first ProviderScope.
      await tester.pumpWidget(const SizedBox());
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

      expect(
        find.text('Mưa bắt đầu sau khoảng 30 phút'),
        cachedAt == null ? findsOneWidget : findsNothing,
      );
    }
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
