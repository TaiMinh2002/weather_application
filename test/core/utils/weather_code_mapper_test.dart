import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_application/core/utils/weather_code_mapper.dart';

void main() {
  test('fromCode groups WMO codes', () {
    const cases = {
      0: WeatherCondition.clear,
      1: WeatherCondition.mainlyClear,
      2: WeatherCondition.partlyCloudy,
      3: WeatherCondition.overcast,
      48: WeatherCondition.fog,
      55: WeatherCondition.drizzle,
      65: WeatherCondition.rain,
      81: WeatherCondition.showers,
      75: WeatherCondition.snow,
      99: WeatherCondition.thunderstorm,
      42: WeatherCondition.unknown,
    };
    cases.forEach((code, expected) {
      expect(WeatherCondition.fromCode(code), expected, reason: 'code $code');
    });
  });

  test('clear sky icon depends on day/night', () {
    expect(WeatherCondition.clear.icon(), Icons.wb_sunny);
    expect(WeatherCondition.clear.icon(isDay: false), Icons.nightlight_round);
  });
}
