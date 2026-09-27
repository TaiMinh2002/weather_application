import 'package:flutter_test/flutter_test.dart';
import 'package:weather_application/core/utils/weather_code_mapper.dart';
import 'package:weather_application/features/weather/domain/entities/weather.dart';

void main() {
  test('UvLevel.fromIndex follows WHO bands', () {
    final cases = {
      0.0: UvLevel.low,
      2.4: UvLevel.low,
      2.6: UvLevel.moderate,
      5.0: UvLevel.moderate,
      7.0: UvLevel.high,
      8.0: UvLevel.veryHigh,
      10.4: UvLevel.veryHigh,
      11.0: UvLevel.extreme,
    };
    cases.forEach((uv, level) => expect(UvLevel.fromIndex(uv), level));
  });

  test('CompassPoint.fromDegrees rounds to the nearest of 8 points', () {
    const cases = {
      0: CompassPoint.n,
      22: CompassPoint.n,
      23: CompassPoint.ne,
      135: CompassPoint.se,
      270: CompassPoint.w,
      338: CompassPoint.n,
      360: CompassPoint.n,
    };
    cases.forEach((deg, point) => expect(CompassPoint.fromDegrees(deg), point));
  });

  test('AqiLevel.fromUsAqi follows US EPA breakpoints', () {
    const cases = {
      0: AqiLevel.good,
      50: AqiLevel.good,
      51: AqiLevel.moderate,
      150: AqiLevel.sensitive,
      174: AqiLevel.unhealthy,
      300: AqiLevel.veryUnhealthy,
      301: AqiLevel.hazardous,
    };
    cases.forEach((aqi, level) => expect(AqiLevel.fromUsAqi(aqi), level));
  });

  group('tipsFor', () {
    test('a mild, dry day suggests going out', () {
      expect(tipsFor(_weather(), null), [WeatherTip.niceDay]);
    });

    test('rules fire on their thresholds, most important first', () {
      expect(
        tipsFor(
          _weather(
            hourly: WeatherCondition.thunderstorm,
            rainChance: 50,
            feelsLike: 36,
            uvMax: 8,
          ),
          const AirQuality(usAqi: 101),
        ),
        [WeatherTip.storm, WeatherTip.umbrella, WeatherTip.mask],
      );
      expect(tipsFor(_weather(rainChance: 49), null), [WeatherTip.niceDay]);
      expect(tipsFor(_weather(condition: WeatherCondition.drizzle), null), [
        WeatherTip.umbrella,
      ]);
    });

    test('sunscreen only in daytime; cold and wind rules', () {
      expect(tipsFor(_weather(uvMax: 6), null), [WeatherTip.sunscreen]);
      expect(tipsFor(_weather(uvMax: 9, isDay: false), null), [
        WeatherTip.niceDay,
      ]);
      expect(tipsFor(_weather(feelsLike: 12, wind: 40), null), [
        WeatherTip.jacket,
        WeatherTip.wind,
      ]);
      expect(tipsFor(_weather(), const AirQuality(usAqi: 100)), [
        WeatherTip.niceDay,
      ]);
    });
  });
}

Weather _weather({
  WeatherCondition condition = WeatherCondition.clear,
  WeatherCondition hourly = WeatherCondition.clear,
  int rainChance = 0,
  double feelsLike = 25,
  double uvMax = 3,
  bool isDay = true,
  double wind = 10,
}) {
  final now = DateTime(2026, 9, 26, 10);
  return Weather(
    current: CurrentWeather(
      time: now,
      temperature: feelsLike,
      apparentTemperature: feelsLike,
      humidity: 60,
      dewPoint: 15,
      isDay: isDay,
      condition: condition,
      windSpeed: wind,
      windDirection: 0,
      pressure: 1010,
      uvIndex: uvMax,
      visibility: 10000,
    ),
    hourly: [
      for (var h = 0; h < 24; h++)
        HourlyForecast(
          time: now.add(Duration(hours: h)),
          temperature: feelsLike,
          condition: hourly,
          precipitationProbability: rainChance,
          isDay: isDay,
        ),
    ],
    daily: [
      DailyForecast(
        date: DateTime(2026, 9, 26),
        condition: condition,
        tempMax: 30,
        tempMin: 20,
        sunrise: now,
        sunset: now,
        uvIndexMax: uvMax,
        precipitationProbabilityMax: rainChance,
        windSpeedMax: wind,
        windDirectionDominant: 0,
      ),
    ],
  );
}
