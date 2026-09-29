import 'dart:math' as math;

import '../../../core/utils/weather_code_mapper.dart';
import '../../weather/domain/entities/weather.dart';

/// Outdoor plans scored hour by hour. Declaration order is display order.
enum Activity {
  motorbike(hours: 1),
  laundry(hours: 3),
  running(hours: 1),
  cycling(hours: 2),
  carWash(hours: 1),
  picnic(hours: 2);

  const Activity({required this.hours});

  /// How many hours in a row [bestWindow] looks for: laundry needs a few dry
  /// hours, a run needs one.
  final int hours;

  /// Pre-selected until the user picks: everyday plans in Vietnam.
  static const defaults = {motorbike, laundry, running};
}

enum ActivityLevel {
  great,
  good,
  fair,
  poor;

  static ActivityLevel fromScore(int score) => switch (score) {
    >= 80 => great,
    >= 60 => good,
    >= 40 => fair,
    _ => poor,
  };
}

typedef ActivityWindow = ({DateTime from, DateTime to, int score});

/// How good hours[i] is for [a], 0–100. Takes the whole list because a car
/// wash also depends on the day after.
int scoreAt(Activity a, List<HourlyForecast> hours, int i, {AirQuality? air}) {
  final h = hours[i];
  if (h.condition == WeatherCondition.thunderstorm || h.precipitation >= 0.5) {
    return 0;
  }
  // Points lost per unit past a comfort limit.
  double over(num value, num limit, double perUnit) =>
      value > limit ? (value - limit) * perUnit : 0;
  double under(num value, num limit, double perUnit) =>
      value < limit ? (limit - value) * perUnit : 0;
  final feels = h.apparentTemperature;
  final rain = h.precipitationProbability;
  // There is no hourly AQI, so the current value stands in for the day.
  final smog = air == null ? 0.0 : over(air.usAqi, 100, 0.8);
  final penalty = switch (a) {
    // Even a drizzle soaks a rider.
    Activity.motorbike =>
      rain * 0.8 +
          h.precipitation * 150 +
          over(h.windSpeed, 40, 2) +
          over(feels, 36, 5),
    Activity.laundry when !h.isDay || h.precipitation > 0 => 100.0,
    Activity.laundry =>
      rain +
          over(h.humidity, 60, 1.5) +
          (h.condition == WeatherCondition.overcast ||
                  h.condition == WeatherCondition.fog
              ? 20
              : 0),
    Activity.running =>
      rain * 0.4 +
          over(feels, 27, 6) +
          under(feels, 10, 4) +
          over(h.uvIndex, 5, 8) +
          over(h.windSpeed, 30, 2) +
          smog,
    Activity.cycling =>
      rain * 0.5 +
          over(feels, 29, 5) +
          under(feels, 10, 4) +
          over(h.uvIndex, 6, 6) +
          over(h.windSpeed, 20, 3) +
          smog,
    // A wash is wasted if it rains within the next day.
    Activity.carWash => [
      for (final later in hours.skip(i).take(24))
        later.precipitationProbability,
    ].reduce(math.max).toDouble(),
    Activity.picnic when !h.isDay => 100.0,
    Activity.picnic =>
      rain * 0.8 +
          over(feels, 31, 6) +
          under(feels, 18, 4) +
          over(h.uvIndex, 7, 6) +
          over(h.windSpeed, 25, 2),
  };
  return (100 - penalty).clamp(0, 100).round();
}

/// Best [Activity.hours]-long block on [from]'s date, starting no earlier
/// than [from]'s hour and inside 5:00–21:00. A block is as good as its worst
/// hour (one shower ruins the laundry); ties go to the earliest. Null when no
/// block fits in what's left of the day.
ActivityWindow? bestWindow(
  Activity a,
  List<HourlyForecast> hours, {
  required DateTime from,
  AirQuality? air,
}) {
  final start = DateTime(from.year, from.month, from.day, from.hour);
  final end = DateTime(from.year, from.month, from.day, 21);
  ActivityWindow? best;
  for (var i = 0; i + a.hours <= hours.length; i++) {
    final t = hours[i].time;
    if (t.isBefore(start) || t.hour < 5) continue;
    final to = hours[i + a.hours - 1].time.add(const Duration(hours: 1));
    if (to.isAfter(end)) break;
    final score = [
      for (var j = i; j < i + a.hours; j++) scoreAt(a, hours, j, air: air),
    ].reduce(math.min);
    if (best == null || score > best.score) {
      best = (from: t, to: to, score: score);
    }
  }
  return best;
}
