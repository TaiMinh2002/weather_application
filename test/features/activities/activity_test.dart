import 'package:flutter_test/flutter_test.dart';
import 'package:weather_application/core/utils/weather_code_mapper.dart';
import 'package:weather_application/features/activities/domain/activity.dart';
import 'package:weather_application/features/weather/domain/entities/weather.dart';

final _day = DateTime(2026, 9, 26);

/// 48 pleasant hours from [_day] midnight; [edit] tweaks single hours.
List<HourlyForecast> _hours({
  HourlyForecast Function(int hour, HourlyForecast h)? edit,
}) => [
  for (var i = 0; i < 48; i++)
    (edit ?? (_, h) => h)(
      i,
      HourlyForecast(
        time: _day.add(Duration(hours: i)),
        temperature: 22,
        condition: WeatherCondition.clear,
        precipitationProbability: 0,
        isDay: i % 24 >= 6 && i % 24 < 18,
        apparentTemperature: 22,
        precipitation: 0,
        windSpeed: 5,
        uvIndex: 2,
        humidity: 50,
      ),
    ),
];

HourlyForecast _with(
  HourlyForecast h, {
  WeatherCondition? condition,
  int? rainChance,
  double? feels,
  double? mm,
  double? uv,
}) => HourlyForecast(
  time: h.time,
  temperature: h.temperature,
  condition: condition ?? h.condition,
  precipitationProbability: rainChance ?? h.precipitationProbability,
  isDay: h.isDay,
  apparentTemperature: feels ?? h.apparentTemperature,
  precipitation: mm ?? h.precipitation,
  windSpeed: h.windSpeed,
  uvIndex: uv ?? h.uvIndex,
  humidity: h.humidity,
);

void main() {
  test('ActivityLevel.fromScore bands', () {
    const cases = {
      100: ActivityLevel.great,
      80: ActivityLevel.great,
      79: ActivityLevel.good,
      60: ActivityLevel.good,
      40: ActivityLevel.fair,
      39: ActivityLevel.poor,
      0: ActivityLevel.poor,
    };
    cases.forEach((s, level) => expect(ActivityLevel.fromScore(s), level));
  });

  group('scoreAt', () {
    test('storms and real rain rule everything out', () {
      final hours = _hours(
        edit: (i, h) => switch (i) {
          10 => _with(h, condition: WeatherCondition.thunderstorm),
          11 => _with(h, mm: 0.5),
          _ => h,
        },
      );
      for (final a in Activity.values) {
        expect(scoreAt(a, hours, 10), 0, reason: a.name);
        expect(scoreAt(a, hours, 11), 0, reason: a.name);
      }
    });

    test('a mild, dry daytime hour is great for everything', () {
      final hours = _hours();
      for (final a in Activity.values) {
        expect(scoreAt(a, hours, 9), 100, reason: a.name);
      }
    });

    test('running loses points to heat, UV and smog', () {
      final hours = _hours(
        edit: (i, h) => i == 12 ? _with(h, feels: 33, uv: 7) : h,
      );
      // 6 × (33 − 27) + 8 × (7 − 5)
      expect(scoreAt(Activity.running, hours, 12), 48);
      // 0.8 × (150 − 100)
      expect(
        scoreAt(Activity.running, hours, 9, air: const AirQuality(usAqi: 150)),
        60,
      );
      expect(
        scoreAt(
          Activity.motorbike,
          hours,
          9,
          air: const AirQuality(usAqi: 300),
        ),
        100,
      );
    });

    test('drizzle soaks a rider and the laundry', () {
      final hours = _hours(edit: (i, h) => i == 9 ? _with(h, mm: 0.3) : h);
      expect(scoreAt(Activity.motorbike, hours, 9), 55);
      expect(scoreAt(Activity.laundry, hours, 9), 0);
      expect(scoreAt(Activity.running, hours, 9), 100);
    });

    test('laundry and picnics need daylight', () {
      final hours = _hours();
      expect(scoreAt(Activity.laundry, hours, 20), 0);
      expect(scoreAt(Activity.picnic, hours, 20), 0);
      expect(scoreAt(Activity.running, hours, 20), 100);
    });

    test('a car wash looks at the next 24 hours', () {
      final hours = _hours(
        edit: (i, h) => i == 30 ? _with(h, rainChance: 70) : h,
      );
      expect(scoreAt(Activity.carWash, hours, 9), 30);
      expect(scoreAt(Activity.carWash, hours, 5), 100);
    });
  });

  group('bestWindow', () {
    test('picks the block whose worst hour is best, earliest on ties', () {
      // A likely shower at 8:00 spoils every laundry block that includes it.
      final hours = _hours(
        edit: (i, h) => i == 8 ? _with(h, rainChance: 60) : h,
      );
      expect(bestWindow(Activity.running, hours, from: _day), (
        from: DateTime(2026, 9, 26, 5),
        to: DateTime(2026, 9, 26, 6),
        score: 100,
      ));
      expect(bestWindow(Activity.laundry, hours, from: _day), (
        from: DateTime(2026, 9, 26, 9),
        to: DateTime(2026, 9, 26, 12),
        score: 100,
      ));
    });

    test('starts no earlier than from and ends by 21:00', () {
      final hours = _hours();
      expect(
        bestWindow(
          Activity.running,
          hours,
          from: _day.add(const Duration(hours: 14, minutes: 30)),
        )!.from,
        DateTime(2026, 9, 26, 14),
      );
      expect(
        bestWindow(
          Activity.laundry,
          hours,
          from: _day.add(const Duration(hours: 19)),
        ),
        isNull,
      );
      expect(
        bestWindow(
          Activity.running,
          hours,
          from: _day.add(const Duration(hours: 20)),
        )!.to,
        DateTime(2026, 9, 26, 21),
      );
    });
  });
}
