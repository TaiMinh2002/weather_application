enum TempUnit { celsius, fahrenheit }

enum WindUnit { kmh, ms }

/// Open-Meteo values arrive in °C and km/h; this formats them in the units
/// chosen in Settings.
class Units {
  const Units({this.temp = TempUnit.celsius, this.wind = WindUnit.kmh});

  final TempUnit temp;
  final WindUnit wind;

  String formatTemp(double celsius) => switch (temp) {
    TempUnit.celsius => '${celsius.round()}°',
    TempUnit.fahrenheit => '${(celsius * 9 / 5 + 32).round()}°',
  };

  /// A temperature difference, unsigned: no +32 offset for °F.
  String formatTempDelta(double celsius) => switch (temp) {
    TempUnit.celsius => '${celsius.abs().round()}°',
    TempUnit.fahrenheit => '${(celsius.abs() * 9 / 5).round()}°',
  };

  String formatWind(double kmh) => switch (wind) {
    WindUnit.kmh => '${kmh.round()} km/h',
    // m/s values are small (12 km/h ≈ 3.3 m/s), so keep one decimal.
    WindUnit.ms => '${(kmh / 3.6).toStringAsFixed(1)} m/s',
  };
}
