import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/share/presentation/share_card.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/features/weather/domain/entities/weather.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../weather/data/weather_fixture.dart';

Future<void> _pump(WidgetTester tester, Map<String, dynamic> json) async {
  SharedPreferences.setMockInitialValues({
    // Running only, so the fixture's borderline hour decides the line.
    PrefKeys.activities: ['running'],
  });
  final prefs = await SharedPreferences.getInstance();
  // Room for the card's fixed 360×640 layout.
  tester.view.physicalSize = const Size(400, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: ShareCard(
            weather: WeatherDto.fromJson(json).toEntity(),
            name: 'Hà Nội',
            air: const AirQuality(usAqi: 74),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows place, temperature and attribution', (tester) async {
    await _pump(tester, weatherJson());

    expect(find.text('Hà Nội'), findsOneWidget);
    // The current temperature and the first hourly column.
    expect(find.text('30°'), findsNWidgets(2));
    expect(find.text('C:32° T:25° · Cảm giác như 35°'), findsOneWidget);
    expect(find.text('Skycast · Open-Meteo'), findsOneWidget);
    // Stats: daily rain chance, UV, AQI with its level, wind.
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('74'), findsOneWidget);
    expect(find.text('Trung bình'), findsOneWidget);
    // Six columns, every other hour from now.
    expect(find.text('Bây giờ'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    // The picked activity with its best time left today.
    expect(find.text('Chạy bộ'), findsOneWidget);
    expect(find.text('10:00–11:00'), findsOneWidget);
    expect(find.text('Tạm được'), findsOneWidget);
  });

  testWidgets('leads with rain about to start, else the top tip', (
    tester,
  ) async {
    final json = weatherJson()
      ..['minutely_15'] = {
        'time': ['2026-09-24T10:15', '2026-09-24T10:30'],
        'precipitation': [0.0, 0.8],
      };
    await _pump(tester, json);

    expect(find.text('Mưa bắt đầu sau khoảng 15 phút'), findsOneWidget);

    await _pump(tester, weatherJson());
    expect(
      find.text('Trời nóng, uống đủ nước và tránh nắng gắt'),
      findsOneWidget,
    );
  });
}
