import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/cities/data/datasources/cities_local_ds.dart';
import 'package:weather_application/features/cities/data/datasources/cities_remote_ds.dart';
import 'package:weather_application/features/cities/data/datasources/cities_sync_ds.dart';
import 'package:weather_application/features/cities/data/models/city_dto.dart';
import 'package:weather_application/features/cities/data/repositories/cities_repository_impl.dart';
import 'package:weather_application/features/cities/domain/entities/city.dart';
import 'package:weather_application/features/cities/presentation/providers/cities_provider.dart';
import 'package:weather_application/features/cities/presentation/screens/cities_screen.dart';
import 'package:weather_application/features/location/presentation/providers/location_provider.dart';
import 'package:weather_application/l10n/app_localizations.dart';

class _MockRemote extends Mock implements CitiesRemoteDataSource {}

class _MockSync extends Mock implements CitiesSyncDataSource {}

const _hue = City(
  id: 1580240,
  name: 'Huế',
  lat: 16.46,
  lon: 107.6,
  region: 'Thừa Thiên Huế',
  country: 'Việt Nam',
);
const _danang = City(id: 1583992, name: 'Đà Nẵng', lat: 16.07, lon: 108.22);
const _hanoi = City(id: 1581130, name: 'Hà Nội', lat: 21.02, lon: 105.84);

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('CityDto parses a geocoding result and keeps optional fields', () {
    final city = CityDto.fromJson({
      'id': 1580240,
      'name': 'Huế',
      'latitude': 16.4619,
      'longitude': 107.59546,
      'elevation': 11.0,
      'admin1': 'Thừa Thiên Huế',
      'country': 'Việt Nam',
    }).toEntity();

    expect(city.area, 'Thừa Thiên Huế, Việt Nam');
    expect(const City(id: 1, name: 'X', lat: 0, lon: 0).area, '');
  });

  group('CitiesRepositoryImpl', () {
    late _MockRemote remote;
    late CitiesRepositoryImpl repo;

    setUp(() async {
      remote = _MockRemote();
      repo = CitiesRepositoryImpl(
        remote,
        CitiesLocalDataSource(await _prefs()),
        const Locale('vi'),
        null,
      );
    });

    test('search passes the locale language and maps results', () async {
      when(() => remote.search('hue', 'vi'))
          .thenAnswer((_) async => [CityDto.fromEntity(_hue)]);

      final result = await repo.search('hue');
      expect((result as Ok<List<City>>).data.single.name, 'Huế');
    });

    test('search maps NetworkException to NetworkFailure', () async {
      when(() => remote.search(any(), any()))
          .thenThrow(const NetworkException());

      final result = await repo.search('hue');
      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('saved cities round-trip in order', () async {
      await repo.saveCities([_hue, _danang]);
      expect(repo.savedCities().map((c) => c.name), ['Huế', 'Đà Nẵng']);
    });
  });

  group('cloud backup', () {
    late _MockSync sync;
    late CitiesLocalDataSource local;
    late CitiesRepositoryImpl repo;

    setUpAll(() => registerFallbackValue(<CityDto>[]));

    setUp(() async {
      sync = _MockSync();
      local = CitiesLocalDataSource(await _prefs());
      repo = CitiesRepositoryImpl(
        _MockRemote(),
        local,
        const Locale('vi'),
        sync,
      );
      when(() => sync.push(any())).thenAnswer((_) async {});
    });

    test('saving writes locally and pushes the whole list', () async {
      await repo.saveCities([_hue, _danang]);

      expect(repo.savedCities().length, 2);
      final pushed = verify(() => sync.push(captureAny())).captured.single;
      expect((pushed as List<CityDto>).map((c) => c.name), ['Huế', 'Đà Nẵng']);
    });

    test('a failed push still keeps the local save', () async {
      when(() => sync.push(any())).thenThrow(const NetworkException());

      await repo.saveCities([_hue]);
      expect(repo.savedCities().single.name, 'Huế');
    });

    test('on start, an empty device restores the cloud copy', () async {
      when(sync.pull).thenAnswer((_) async => [CityDto.fromEntity(_hanoi)]);

      final restored = await repo.syncOnStart();

      expect(restored?.single.name, 'Hà Nội');
      expect(repo.savedCities().single.name, 'Hà Nội');
      verifyNever(() => sync.push(any()));
    });

    test('on start, a device with cities backs them up instead', () async {
      await local.write([CityDto.fromEntity(_hue)]);

      expect(await repo.syncOnStart(), isNull);
      verifyNever(sync.pull);
      verify(() => sync.push(any())).called(1);
    });

    test('on start, a failed pull changes nothing', () async {
      when(sync.pull).thenThrow(const NetworkException());

      expect(await repo.syncOnStart(), isNull);
      expect(repo.savedCities(), isEmpty);
    });
  });

  group('SavedCities', () {
    late SharedPreferences prefs;
    late ProviderContainer container;
    SavedCities notifier() => container.read(savedCitiesProvider.notifier);
    List<String> names() => [
      for (final c in container.read(savedCitiesProvider)) c.name,
    ];

    setUp(() async {
      prefs = await _prefs();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('add ignores duplicates; remove, insert and move persist', () async {
      await notifier().add(_hue);
      await notifier().add(_danang);
      await notifier().add(_hue);
      expect(names(), ['Huế', 'Đà Nẵng']);

      await notifier().add(_hanoi);
      await notifier().move(2, 0);
      expect(names(), ['Hà Nội', 'Huế', 'Đà Nẵng']);

      await notifier().remove(_huePlaceholder);
      await notifier().insert(1, _hue);
      expect(names(), ['Hà Nội', 'Huế', 'Đà Nẵng']);

      final reopened = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(reopened.dispose);
      expect(reopened.read(savedCitiesProvider).map((c) => c.name), [
        'Hà Nội',
        'Huế',
        'Đà Nẵng',
      ]);
    });
  });

  testWidgets('empty saved list shows the empty view', (tester) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutoRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentPlaceProvider.overrideWith(
            (ref) async => throw const LocationFailure(LocationError.denied),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CitiesScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chưa lưu thành phố nào'), findsOneWidget);
    expect(find.text('Tìm thành phố…'), findsOneWidget);
  });
}

/// Same id as [_hue]: removal matches by id, not identity.
const _huePlaceholder = City(id: 1580240, name: '', lat: 0, lon: 0);
