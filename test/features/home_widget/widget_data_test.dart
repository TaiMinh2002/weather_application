import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/core/utils/unit_converter.dart';
import 'package:weather_application/core/utils/weather_code_mapper.dart';
import 'package:weather_application/features/home_widget/presentation/widget_data.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/l10n/app_localizations.dart';

import '../weather/data/weather_fixture.dart';

void main() {
  test('Sky groups conditions and names the native background', () {
    expect(Sky.of(WeatherCondition.mainlyClear), Sky.clear);
    expect(Sky.of(WeatherCondition.showers), Sky.rain);
    expect(Sky.of(WeatherCondition.unknown), Sky.cloudy);
    expect(Sky.rain.key(isDay: false), 'rain_night');
  });

  test('widgetData is pre-formatted in the chosen language and units', () {
    final weather = WeatherDto.fromJson(weatherJson()).toEntity();

    final vi = widgetData(
      weather,
      'Hà Nội',
      lookupAppLocalizations(const Locale('vi')),
      const Units(),
    );
    expect(vi, {
      'city': 'Hà Nội',
      'temp': '30°',
      'condition': 'Có mây',
      'hilo': 'C:32° T:25°',
      'sky': 'cloudy_day',
    });

    final en = widgetData(
      weather,
      'Hanoi',
      lookupAppLocalizations(const Locale('en')),
      const Units(temp: TempUnit.fahrenheit),
    );
    expect(en['temp'], '87°');
    expect(en['hilo'], 'H:90° L:77°');
  });
}
