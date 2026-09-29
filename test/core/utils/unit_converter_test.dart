import 'package:flutter_test/flutter_test.dart';
import 'package:weather_application/core/utils/unit_converter.dart';

void main() {
  test('formatTemp rounds and converts to Fahrenheit', () {
    const c = Units();
    const f = Units(temp: TempUnit.fahrenheit);
    expect(c.formatTemp(30.4), '30°');
    expect(c.formatTemp(-2.6), '-3°');
    expect(f.formatTemp(0), '32°');
    expect(f.formatTemp(30.4), '87°');
    expect(f.formatTemp(-40), '-40°');
  });

  test('formatTempDelta is unsigned and has no Fahrenheit offset', () {
    const c = Units();
    const f = Units(temp: TempUnit.fahrenheit);
    expect(c.formatTempDelta(-3.4), '3°');
    expect(f.formatTempDelta(5), '9°');
  });

  test('formatWind converts km/h to m/s with one decimal', () {
    expect(const Units().formatWind(12.4), '12 km/h');
    expect(const Units(wind: WindUnit.ms).formatWind(12), '3.3 m/s');
    expect(const Units(wind: WindUnit.ms).formatWind(0), '0.0 m/s');
  });
}
