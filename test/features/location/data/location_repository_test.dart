import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/features/location/data/datasources/location_ds.dart';
import 'package:weather_application/features/location/data/repositories/location_repository_impl.dart';
import 'package:weather_application/features/location/domain/entities/place.dart';

class _MockDs extends Mock implements LocationDataSource {}

final _position = Position(
  latitude: 21.03,
  longitude: 105.85,
  timestamp: DateTime(2026),
  accuracy: 0,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _MockDs ds;
  late LocationRepositoryImpl repo;

  setUpAll(() => registerFallbackValue(const Locale('vi')));

  setUp(() {
    ds = _MockDs();
    repo = LocationRepositoryImpl(ds, const Locale('vi'));
    when(() => ds.isServiceEnabled()).thenAnswer((_) async => true);
    when(() => ds.checkPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => ds.getPosition()).thenAnswer((_) async => _position);
    when(() => ds.placeName(any(), any(), any()))
        .thenAnswer((_) async => 'Hà Nội');
  });

  Future<LocationError> failureReason() async {
    final result = await repo.getCurrentPlace();
    return ((result as Err).failure as LocationFailure).reason;
  }

  test('returns place with name when everything is granted', () async {
    final place = (await repo.getCurrentPlace()) as Ok<Place>;
    expect(place.data.lat, 21.03);
    expect(place.data.name, 'Hà Nội');
  });

  test('service disabled', () async {
    when(() => ds.isServiceEnabled()).thenAnswer((_) async => false);
    expect(await failureReason(), LocationError.serviceDisabled);
    verifyNever(() => ds.checkPermission());
  });

  test('requests permission once, then denied', () async {
    when(() => ds.checkPermission())
        .thenAnswer((_) async => LocationPermission.denied);
    when(() => ds.requestPermission())
        .thenAnswer((_) async => LocationPermission.denied);
    expect(await failureReason(), LocationError.denied);
  });

  test('granted after request', () async {
    when(() => ds.checkPermission())
        .thenAnswer((_) async => LocationPermission.denied);
    when(() => ds.requestPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    expect(await repo.getCurrentPlace(), isA<Ok<Place>>());
  });

  test('denied forever does not re-request', () async {
    when(() => ds.checkPermission())
        .thenAnswer((_) async => LocationPermission.deniedForever);
    expect(await failureReason(), LocationError.deniedForever);
    verifyNever(() => ds.requestPermission());
  });

  test('position unavailable', () async {
    when(() => ds.getPosition())
        .thenThrow(const LocationException(LocationError.unavailable));
    expect(await failureReason(), LocationError.unavailable);
  });

  test('reverse geocoding failure still returns the place', () async {
    when(() => ds.placeName(any(), any(), any())).thenThrow(Exception('x'));
    final place = (await repo.getCurrentPlace()) as Ok<Place>;
    expect(place.data.name, isNull);
  });
}
