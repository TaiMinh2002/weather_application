import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/utils/weather_code_mapper.dart';
import 'package:weather_application/features/weather/data/datasources/weather_remote_ds.dart';
import 'package:weather_application/features/weather/data/models/weather_dto.dart';
import 'package:weather_application/features/weather/data/repositories/weather_repository_impl.dart';

import 'weather_fixture.dart';

class _MockRemote extends Mock implements WeatherRemoteDataSource {}

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
    late WeatherRepositoryImpl repo;

    setUp(() {
      remote = _MockRemote();
      repo = WeatherRepositoryImpl(remote);
    });

    test('returns Ok with entity on success', () async {
      when(
        () => remote.getForecast(any(), any()),
      ).thenAnswer((_) async => WeatherDto.fromJson(weatherJson()));

      final result = await repo.getWeather(lat: 21, lon: 105);
      expect(result, isA<Ok>());
    });

    test('maps NetworkException to NetworkFailure', () async {
      when(
        () => remote.getForecast(any(), any()),
      ).thenThrow(const NetworkException());

      final result = await repo.getWeather(lat: 21, lon: 105);
      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.getForecast(any(), any()),
      ).thenThrow(const ServerException(500));

      final result = await repo.getWeather(lat: 21, lon: 105);
      expect((result as Err).failure, isA<ServerFailure>());
    });
  });
}
