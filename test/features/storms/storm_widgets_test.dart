import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/location/domain/entities/place.dart';
import 'package:weather_application/features/storms/domain/entities/storm.dart';
import 'package:weather_application/features/storms/presentation/providers/storms_provider.dart';
import 'package:weather_application/features/storms/presentation/screens/storm_screen.dart';
import 'package:weather_application/features/storms/presentation/widgets/storm_card.dart';
import 'package:weather_application/l10n/app_localizations.dart';

const _daNang = Place(lat: 16.05, lon: 108.2, name: 'Đà Nẵng');

/// Heading west across the South China Sea for Da Nang, strengthening.
final _storm = Storm(
  id: 'TC2640',
  name: 'Kajiki',
  issuedAt: DateTime.utc(2026, 10, 2, 3),
  track: const [(lat: 14.5, lon: 125.0), (lat: 15.0, lon: 118.0)],
  points: [
    StormPoint(
      time: DateTime.utc(2026, 10, 2),
      hoursAhead: 0,
      lat: 15.0,
      lon: 118.0,
      windMs: 26,
      gustMs: 35,
      pressure: 975,
    ),
    StormPoint(
      time: DateTime.utc(2026, 10, 3),
      hoursAhead: 24,
      lat: 15.8,
      lon: 111.0,
      windMs: 33,
      gustMs: 45,
      pressure: 960,
      radiusKm: 120,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Future<List<Storm>> Function() storms,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  // A fresh tree each time, or a second pump would keep the old overrides.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeStormsProvider.overrideWith((ref) => storms()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the card shows a storm heading for the user', (tester) async {
    await _pump(tester, const StormCard(place: _daNang), () async => [_storm]);

    expect(find.text('Bão mạnh Kajiki'), findsOneWidget);
    expect(find.text('Gió cấp 10 (94 km/h), giật cấp 12'), findsOneWidget);
    expect(
      find.text('Cách bạn 1056 km · gần nhất ~301 km sau 24 giờ'),
      findsOneWidget,
    );
  });

  testWidgets('the card stays out of the way when no storm is near', (
    tester,
  ) async {
    const norway = Place(lat: 60, lon: 10);
    await _pump(tester, const StormCard(place: norway), () async => [_storm]);
    expect(find.byType(Text), findsNothing);

    await _pump(
      tester,
      const StormCard(place: _daNang),
      () async => throw const NetworkFailure(),
    );
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the storm screen lists now and each forecast time', (
    tester,
  ) async {
    await _pump(
      tester,
      const StormScreen(id: 'TC2640', place: _daNang),
      () async => [_storm],
    );

    expect(find.text('Bão mạnh Kajiki'), findsWidgets);
    expect(find.text('Bây giờ'), findsOneWidget);
    expect(find.text('Bão rất mạnh Kajiki'), findsOneWidget);
    expect(
      find.text(
        'Gió cấp 12 (119 km/h), giật cấp 14 · 960 hPa · Cách bạn 301 km',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Cơ quan Khí tượng Nhật Bản'), findsOneWidget);
  });

  testWidgets('the storm screen shows a skeleton while loading', (
    tester,
  ) async {
    await _pump(
      tester,
      const StormScreen(id: 'TC2640', place: _daNang),
      () => Completer<List<Storm>>().future,
    );
    // Skeletonizer is abstract; the widget in the tree is a private subclass.
    expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a storm that has ended says so; errors offer a retry', (
    tester,
  ) async {
    await _pump(
      tester,
      const StormScreen(id: 'TC0000', place: _daNang),
      () async => [_storm],
    );
    expect(find.text('Cơn bão này không còn được theo dõi.'), findsOneWidget);

    await _pump(
      tester,
      const StormScreen(id: 'TC2640', place: _daNang),
      () async => throw const NetworkFailure(),
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
