import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/features/storms/data/datasources/storms_remote_ds.dart';
import 'package:weather_application/features/storms/data/models/storm_dto.dart';
import 'package:weather_application/features/storms/data/repositories/storms_repository_impl.dart';
import 'package:weather_application/features/storms/domain/entities/storm.dart';

import 'storm_fixture.dart';

class _MockRemote extends Mock implements StormsRemoteDataSource {}

StormDto _surigae() => StormDto(
  id: 'TC2632',
  specs: [
    for (final p in (jsonDecode(
      specificationsJson,
    ) as List).cast<Map<String, dynamic>>())
      JmaSpecDto.fromJson(p),
  ],
  forecast: [
    for (final p
        in (jsonDecode(forecastJson) as List).cast<Map<String, dynamic>>())
      JmaForecastDto.fromJson(p),
  ],
);

Storm _storm(List<(double, double)> positions) => Storm(
  id: 'TC',
  name: 'Test',
  issuedAt: DateTime.utc(2026, 9, 30),
  track: const [],
  points: [
    for (final (i, (lat, lon)) in positions.indexed)
      StormPoint(
        time: DateTime.utc(2026, 9, 30, i * 12),
        hoursAhead: i * 12,
        lat: lat,
        lon: lon,
      ),
  ],
);

void main() {
  test('beaufort follows the WMO bands, capped at 17', () {
    final cases = {
      0.0: 0,
      10.7: 5,
      10.8: 6,
      17.1: 7,
      17.2: 8,
      18.0: 8,
      25.0: 10,
      32.7: 12,
      51.0: 16,
      70.0: 17,
    };
    cases.forEach((ms, force) => expect(beaufort(ms), force, reason: '$ms'));
  });

  test('StormStrength follows Vietnam\'s classes', () {
    expect(StormStrength.of(null), isNull);
    expect(StormStrength.of(9), isNull, reason: 'force 5 is no cyclone');
    expect(StormStrength.of(12), StormStrength.depression);
    expect(StormStrength.of(18), StormStrength.storm);
    expect(StormStrength.of(26), StormStrength.severe);
    expect(StormStrength.of(40), StormStrength.veryStrong);
    expect(StormStrength.of(55), StormStrength.superTyphoon);
  });

  test('distanceKm: Hanoi to Ho Chi Minh City is about 1140 km', () {
    expect(distanceKm(21.03, 105.85, 10.78, 106.7), closeTo(1140, 10));
    expect(distanceKm(16, 108, 16, 108), 0);
  });

  test('closestApproach and stormsNear use now and forecast points', () {
    // Moving west across the South China Sea towards Da Nang (16, 108).
    final coming = _storm([(15, 125), (15.5, 118), (16, 111)]);
    final far = _storm([(30, 140), (35, 145)]);
    final c = closestApproach(coming, 16, 108);
    expect(c.point.hoursAhead, 24);
    expect(c.km, closeTo(320, 10));
    expect(stormsNear([far, coming], 16, 108), [coming]);
    expect(stormsNear([far], 35, 140), [far]);
  });

  group('StormDto.toEntity (real JMA files)', () {
    final storm = _surigae().toEntity()!;

    test('reads name, analysis and forecast points', () {
      expect(storm.id, 'TC2632');
      expect(storm.name, 'Surigae');
      expect(storm.issuedAt, DateTime.utc(2026, 9, 30, 9, 45));
      expect(storm.points.map((p) => p.hoursAhead), [0, 12, 24, 45]);
      final now = storm.now;
      expect((now.lat, now.lon), (31.7, 138.8));
      expect((now.windMs, now.gustMs, now.pressure), (18, 25, 1000));
      expect(now.radiusKm, isNull);
      expect(storm.points[1].radiusKm, 75);
      expect(storm.points.last.isLow, isTrue);
    });

    test('joins the pre-storm and storm parts of the past track', () {
      expect(storm.track.length, 7);
      expect(storm.track.first, (lat: 14.3, lon: 140.7));
      expect(storm.track.last, (lat: 31.7, lon: 138.8));
    });

    test('unusable files give null instead of throwing', () {
      final broken = StormDto(
        id: 'TC',
        specs: [
          JmaSpecDto.fromJson(const {'part': 'title'}),
        ],
        forecast: const [],
      );
      expect(broken.toEntity(), isNull);
      expect(JmaSpecDto.fromJson(const {'maximumWind': 'odd'}).windMs, isNull);
    });
  });

  group('StormsRepositoryImpl', () {
    late _MockRemote remote;

    setUp(() => remote = _MockRemote());

    test('drops storms that no longer parse, keeps the rest', () async {
      when(remote.getActiveStorms).thenAnswer(
        (_) async => [
          _surigae(),
          const StormDto(id: 'TC0', specs: [], forecast: []),
        ],
      );
      final result = await StormsRepositoryImpl(remote).getActiveStorms();
      expect((result as Ok<List<Storm>>).data.map((s) => s.id), ['TC2632']);
    });

    test('network errors become a NetworkFailure', () async {
      when(remote.getActiveStorms).thenThrow(const NetworkException());
      final result = await StormsRepositoryImpl(remote).getActiveStorms();
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });

  test('the datasource asks JMA for each active storm', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FixtureAdapter();
    final dtos = await StormsRemoteDataSource(dio).getActiveStorms();
    expect(dtos.single.id, 'TC2632');
    expect(dtos.single.toEntity()?.name, 'Surigae');
  });
}

/// Serves the fixture files by URL, so the datasource runs its real code.
class _FixtureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final body = path.endsWith('targetTc.json')
        ? targetTcJson
        : path.endsWith('specifications.json')
        ? specificationsJson
        : forecastJson;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
