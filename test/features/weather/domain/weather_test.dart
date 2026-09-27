import 'package:flutter_test/flutter_test.dart';
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
}
