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
