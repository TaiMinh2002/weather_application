import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/router/app_router.dart';
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/location/data/repositories/location_repository_impl.dart';
import 'package:weather_application/features/location/domain/entities/place.dart';
import 'package:weather_application/features/location/domain/repositories/location_repository.dart';
import 'package:weather_application/features/onboarding/presentation/onboarding_screen.dart';
import 'package:weather_application/l10n/app_localizations.dart';

class _MockLocation extends Mock implements LocationRepository {}

Future<(SharedPreferences, _MockLocation)> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final location = _MockLocation();
  final router = GoRouter(
    initialLocation: Routes.onboarding,
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => const Text('home')),
      GoRoute(path: Routes.cities, builder: (_, _) => const Text('cities')),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationRepositoryProvider.overrideWithValue(location),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  return (prefs, location);
}

void main() {
  testWidgets('allow location asks for permission, then goes Home', (
    tester,
  ) async {
    final (prefs, location) = await _pump(tester);
    when(location.getCurrentPlace).thenAnswer(
      (_) async => const Err<Place>(LocationFailure(LocationError.denied)),
    );

    await tester.tap(find.text('Cho phép vị trí'));
    await tester.pumpAndSettle();

    verify(location.getCurrentPlace).called(1);
    expect(prefs.getBool(PrefKeys.onboarded), isTrue);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('choose a city skips the permission and opens Cities', (
    tester,
  ) async {
    final (prefs, location) = await _pump(tester);

    await tester.tap(find.text('Chọn thành phố thủ công'));
    await tester.pumpAndSettle();

    verifyNever(location.getCurrentPlace);
    expect(prefs.getBool(PrefKeys.onboarded), isTrue);
    expect(find.text('cities'), findsOneWidget);
  });
}
