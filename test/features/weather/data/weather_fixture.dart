/// Trimmed real `/forecast` response shape: 26 hours, 2 days.
Map<String, dynamic> weatherJson() => {
  'current': {
    'time': '2026-09-24T10:15',
    'temperature_2m': 30.4,
    'relative_humidity_2m': 70,
    'apparent_temperature': 35,
    'is_day': 1,
    'weather_code': 2,
    'wind_speed_10m': 8.3,
    'wind_direction_10m': 120,
    'pressure_msl': 1008.1,
    'uv_index': 6.2,
    'visibility': 24140,
  },
  'hourly': {
    'time': [
      for (var h = 0; h < 26; h++)
        DateTime(2026, 9, 24, h).toIso8601String().substring(0, 16),
    ],
    'temperature_2m': [for (var h = 0; h < 26; h++) 25 + h * 0.5],
    'weather_code': List.filled(26, 61),
    'precipitation_probability': [null, ...List.filled(25, 40)],
    'is_day': List.filled(26, 1),
  },
  'daily': {
    'time': ['2026-09-24', '2026-09-25'],
    'weather_code': [2, 95],
    'temperature_2m_max': [32, 31.5],
    'temperature_2m_min': [25.1, 24.8],
    'sunrise': ['2026-09-24T05:53', '2026-09-25T05:53'],
    'sunset': ['2026-09-24T17:56', '2026-09-25T17:55'],
    'uv_index_max': [7.1, null],
    'precipitation_probability_max': [60, 90],
  },
};
