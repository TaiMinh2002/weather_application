import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/share/presentation/share_card.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../weather/data/weather_fixture.dart';

Future<void> _pump(WidgetTester tester, Map<String, dynamic> json) async {
  SharedPreferences.setMockInitialValues({
    // Running only, so the fixture's borderline hour decides the line.
    PrefKeys.activities: ['running'],
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: 340,
            child: ShareCard(
              weather: WeatherDto.fromJson(json).toEntity(),
              name: 'Hà Nội',
            ),
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
    expect(find.text('30°'), findsOneWidget);
    expect(find.text('C:32° T:25° · Cảm giác như 35°'), findsOneWidget);
    expect(find.text('Skycast · Open-Meteo'), findsOneWidget);
    // The fixture's run window only scores "fair", which isn't worth sharing.
    expect(find.textContaining('Chạy bộ'), findsNothing);
  });

  testWidgets('leads with rain that is about to start', (tester) async {
    final json = weatherJson()
      ..['minutely_15'] = {
        'time': ['2026-09-24T10:15', '2026-09-24T10:30'],
        'precipitation': [0.0, 0.8],
      };
    await _pump(tester, json);

    expect(find.text('Mưa bắt đầu sau khoảng 15 phút'), findsOneWidget);
  });
}
