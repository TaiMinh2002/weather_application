import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/core/utils/unit_converter.dart';
import 'package:weather_application/core/utils/weather_code_mapper.dart';
import 'package:weather_application/features/activities/domain/activity.dart';
import 'package:weather_application/features/home_widget/presentation/widget_data.dart';
import 'package:weather_application/features/settings/presentation/providers/settings_provider.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../weather/data/weather_fixture.dart';

void main() {
  final weather = WeatherDto.fromJson(weatherJson()).toEntity();
  final vi = lookupAppLocalizations(const Locale('vi'));

  // The app gets date formats from flutter_localizations; a plain test
  // has to load them itself.
  setUpAll(initializeDateFormatting);

  test('Sky groups conditions and names the native background', () {
    expect(Sky.of(WeatherCondition.mainlyClear), Sky.clear);
    expect(Sky.of(WeatherCondition.showers), Sky.rain);
    expect(Sky.of(WeatherCondition.unknown), Sky.cloudy);
    expect(Sky.rain.key(isDay: false), 'rain_night');
  });

  test('the small widget keys are pre-formatted in language and units', () {
    final data = widgetData(
      weather,
      'Hà Nội',
      vi,
      const AppSettings(),
      locale: 'vi',
    );
    expect(data['city'], 'Hà Nội');
    expect(data['temp'], '30°');
    expect(data['condition'], 'Có mây');
    expect(data['hilo'], 'C:32° T:25°');
    expect(data['sky'], 'cloudy_day');

    final en = widgetData(
      weather,
      'Hanoi',
      lookupAppLocalizations(const Locale('en')),
      const AppSettings(units: Units(temp: TempUnit.fahrenheit)),
      locale: 'en',
    );
    expect(en['temp'], '87°');
    expect(en['hilo'], 'H:90° L:77°');
  });

  test('the medium widget gets six clock-labelled hours from now', () {
    final data = widgetData(
      weather,
      'Hà Nội',
      vi,
      const AppSettings(),
      locale: 'vi',
    );
    // Fixture: now is 10:15, hours from 10:00 at 25 + h / 2 °C, all rain.
    expect(data['h0_time'], '10:00');
    expect(data['h0_temp'], '30°');
    expect(data['h0_icon'], 'rain_day');
    expect(data['h5_time'], '15:00');
    expect(data.containsKey('h6_time'), isFalse);
  });

  test('the activity line only appears for a good window', () {
    String activity(Set<Activity> picks) => widgetData(
      weather,
      'Hà Nội',
      vi,
      AppSettings(activities: picks),
      locale: 'vi',
    )['activity']!;
    // The fixture's light rain and 33° feel only make running "fair".
    expect(activity({Activity.running}), '');
    expect(activity({}), '');
  });
}
