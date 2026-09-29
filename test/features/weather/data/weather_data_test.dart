import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/utils/weather_code_mapper.dart';
import 'package:weather_application/features/weather/data/datasources/weather_local_ds.dart';
import 'package:weather_application/features/weather/data/datasources/weather_remote_ds.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:weather_application/features/weather/domain/entities/weather.dart';

import 'weather_fixture.dart';

class _MockRemote extends Mock implements WeatherRemoteDataSource {}

class _MockLocal extends Mock implements WeatherLocalDataSource {}

void main() {
  group('WeatherDto.toEntity', () {
    final weather = WeatherDto.fromJson(weatherJson()).toEntity();

    test('maps current, ints-as-doubles and nulls', () {
      expect(weather.current.temperature, 30.4);
      expect(weather.current.apparentTemperature, 35.0);
      expect(weather.current.condition, WeatherCondition.partlyCloudy);
      expect(weather.current.isDay, isTrue);
      expect(weather.hourly.first.precipitationProbability, 0);
      expect(weather.daily[1].uvIndexMax, 0);
      expect(weather.daily[1].condition, WeatherCondition.thunderstorm);
    });

    test('hoursOn keeps only that date', () {
      final today = weather.hoursOn(DateTime(2026, 9, 24));
      expect(today.length, 24);
      expect(weather.hoursOn(DateTime(2026, 9, 25)).length, 2);
      expect(weather.daily.first.windFrom, CompassPoint.se);
      expect(weather.daily[1].windSpeedMax, 0);
    });

    test('past day is split off; daily and hourly start today', () {
      final json = weatherJson();
      final hourly = json['hourly'] as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>;
      hourly['time'] = ['2026-09-23T23:00', ...hourly['time'] as List];
      for (final key in hourly.keys.where((k) => k != 'time')) {
        hourly[key] = [(hourly[key] as List)[1], ...hourly[key] as List];
      }
      daily['time'] = ['2026-09-23', ...daily['time'] as List];
      for (final key in daily.keys.where((k) => k != 'time')) {
        daily[key] = [(daily[key] as List)[1], ...daily[key] as List];
      }
      (daily['temperature_2m_max'] as List)[0] = 29;
      json['minutely_15'] = {
        'time': ['2026-09-24T10:15', '2026-09-24T10:30'],
        'precipitation': [0.0, null],
      };

      final w = WeatherDto.fromJson(json).toEntity();

      expect(w.yesterday?.date, DateTime(2026, 9, 23));
      expect(w.yesterday?.tempMax, 29);
      expect(w.daily.first.date, DateTime(2026, 9, 24));
      expect(w.daily.length, 2);
      expect(w.hourly.first.time, DateTime(2026, 9, 24));
      expect(w.nowcast.map((s) => s.mm), [0, 0]);
    });

    test('old caches without the past day or nowcast still map', () {
      expect(weather.yesterday, isNull);
      expect(weather.nowcast, isEmpty);
      expect(weather.daily.first.date, DateTime(2026, 9, 24));
    });

    test('next24Hours starts at the current hour', () {
      final next = weather.next24Hours;
      expect(next.first.time, DateTime(2026, 9, 24, 10));
      // Fixture only has 26 hours, so fewer than 24 remain after 10:00.
      expect(next.length, 16);
    });
  });

  group('WeatherRepositoryImpl', () {
    late _MockRemote remote;
    late _MockLocal local;
    late WeatherRepositoryImpl repo;
    final dto = WeatherDto.fromJson(weatherJson());
    final savedAt = DateTime(2026, 9, 24, 8, 15);

    setUpAll(() {
      registerFallbackValue(dto);
      registerFallbackValue(savedAt);
    });

    setUp(() {
      remote = _MockRemote();
      local = _MockLocal();
      repo = WeatherRepositoryImpl(remote, local);
      when(() => local.save(any(), any(), any(), any()))
          .thenAnswer((_) async {});
    });

    test('online: returns fresh data and caches it', () async {
      when(() => remote.getForecast(any(), any())).thenAnswer((_) async => dto);

      final result = await repo.getWeather(lat: 21, lon: 105);

      expect((result as Ok<Weather>).data.cachedAt, isNull);
      verify(() => local.save(21, 105, dto, any())).called(1);
    });

    test('offline with cache: returns cached data with its time', () async {
      when(() => remote.getForecast(any(), any()))
          .thenThrow(const NetworkException());
      when(() => local.read(any(), any())).thenReturn((dto, savedAt));

      final result = await repo.getWeather(lat: 21, lon: 105);

      expect((result as Ok<Weather>).data.cachedAt, savedAt);
    });

    test('offline without cache: NetworkFailure', () async {
      when(() => remote.getForecast(any(), any()))
          .thenThrow(const NetworkException());
      when(() => local.read(any(), any())).thenReturn(null);

      final result = await repo.getWeather(lat: 21, lon: 105);
      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('air quality maps the response; no coverage is null', () async {
      when(() => remote.getAirQuality(any(), any())).thenAnswer(
        (_) async => AirQualityDto.fromJson({
          'us_aqi': 174,
          'pm2_5': 31.4,
          'pm10': 32.4,
        }),
      );
      final ok = await repo.getAirQuality(lat: 21, lon: 105);
      expect((ok as Ok<AirQuality?>).data?.level, AqiLevel.unhealthy);

      when(() => remote.getAirQuality(any(), any()))
          .thenAnswer((_) async => AirQualityDto.fromJson({'us_aqi': null}));
      final none = await repo.getAirQuality(lat: 0, lon: 0);
      expect((none as Ok<AirQuality?>).data, isNull);
    });

    test('server error: ServerFailure, cache not used', () async {
      when(() => remote.getForecast(any(), any()))
          .thenThrow(const ServerException(500));

      final result = await repo.getWeather(lat: 21, lon: 105);

      expect((result as Err).failure, isA<ServerFailure>());
      verifyNever(() => local.read(any(), any()));
    });
  });

  group('WeatherLocalDataSource', () {
    Future<WeatherLocalDataSource> create(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return WeatherLocalDataSource(await SharedPreferences.getInstance());
    }

    test(
      'round-trips a forecast, rounding nearby coordinates together',
      () async {
        final ds = await create({});
        final savedAt = DateTime(2026, 9, 24, 8, 15);
        await ds.save(
          21.0285,
          105.8542,
          WeatherDto.fromJson(weatherJson()),
          savedAt,
        );

        final (dto, time) = ds.read(21.0301, 105.8512)!;
        expect(time, savedAt);
        expect(dto.toEntity().current.temperature, 30.4);
      },
    );

    test('unreadable entry reads as missing', () async {
      final ds = await create({'weather:21.03,105.85': '{"old":"shape"}'});
      expect(ds.read(21.03, 105.85), isNull);
    });
  });
}
