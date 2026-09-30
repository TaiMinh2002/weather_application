import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/core/utils/unit_converter.dart';
import 'package:weather_application/features/activities/domain/activity.dart';
import 'package:weather_application/features/alerts/data/alerts_sync_ds.dart';
import 'package:weather_application/features/settings/presentation/providers/settings_provider.dart';
import 'package:weather_application/features/weather/domain/entities/weather.dart';
import 'package:weather_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:weather_application/l10n/app_localizations.dart';

Future<ProviderContainer> _container([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to °C, km/h, system theme and device language', () async {
    final settings = (await _container()).read(settingsProvider);
    expect(settings.units.temp, TempUnit.celsius);
    expect(settings.units.wind, WindUnit.kmh);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.locale, isNull);
  });

  test('activities: defaults, persisted picks, empty kept empty', () async {
    expect(
      (await _container()).read(settingsProvider).activities,
      Activity.defaults,
    );
    final container = await _container({
      PrefKeys.activities: ['cycling', 'skydiving'],
    });
    expect(container.read(settingsProvider).activities, {Activity.cycling});

    await container.read(settingsProvider.notifier).setActivities({});
    expect(container.read(settingsProvider).activities, isEmpty);
  });

  test('health: empty by default, persisted, drives limits', () async {
    final container = await _container();
    expect(container.read(settingsProvider).health, isEmpty);
    expect(container.read(settingsProvider).limits.aqi, 100);

    await container.read(settingsProvider.notifier).setHealth({
      HealthProfile.respiratory,
    });
    expect(container.read(settingsProvider).health, {
      HealthProfile.respiratory,
    });
    expect(container.read(settingsProvider).limits.aqi, 50);
  });

  test('weather alerts: off by default, all types until changed', () async {
    final container = await _container();
    final settings = container.read(settingsProvider);
    expect(settings.weatherAlerts, isFalse);
    expect(settings.alertTypes, AlertType.values.toSet());

    final notifier = container.read(settingsProvider.notifier);
    await notifier.setWeatherAlerts(true);
    await notifier.setAlertTypes({AlertType.rain});
    expect(container.read(settingsProvider).weatherAlerts, isTrue);
    expect(container.read(settingsProvider).alertTypes, {AlertType.rain});
  });

  test(
    'setters persist; unknown stored values fall back to defaults',
    () async {
      final container = await _container({PrefKeys.tempUnit: 'kelvin'});
      expect(container.read(settingsProvider).units.temp, TempUnit.celsius);

      final notifier = container.read(settingsProvider.notifier);
      await notifier.setTempUnit(TempUnit.fahrenheit);
      await notifier.setWindUnit(WindUnit.ms);
      await notifier.setThemeMode(ThemeMode.dark);
      await notifier.setLanguage('en');

      final settings = container.read(settingsProvider);
      expect(settings.units.temp, TempUnit.fahrenheit);
      expect(settings.units.wind, WindUnit.ms);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.locale, const Locale('en'));

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(PrefKeys.tempUnit), 'fahrenheit');
      expect(prefs.getString(PrefKeys.language), 'en');
    },
  );

  testWidgets('tapping a segment changes the setting', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Cài đặt'), findsOneWidget);
    await tester.tap(find.text('°F'));
    await tester.tap(find.text('Tối'));
    await tester.pump();

    final settings = container.read(settingsProvider);
    expect(settings.units.temp, TempUnit.fahrenheit);
    expect(settings.themeMode, ThemeMode.dark);
  });
}
