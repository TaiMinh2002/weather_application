import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/cities/presentation/screens/cities_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/weather/presentation/screens/home_screen.dart';
import '../storage/prefs.dart';

part 'app_router.g.dart';

abstract final class Routes {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const cities = '/cities';
  static const settings = '/settings';
  // Add as screens land: /day/:index
}

/// Pure so it can be unit-tested without a widget tree.
String? onboardingRedirect(SharedPreferences prefs, String location) {
  final done = prefs.getBool(PrefKeys.onboarded) ?? false;
  if (!done && location != Routes.onboarding) return Routes.onboarding;
  if (done && location == Routes.onboarding) return Routes.home;
  return null;
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (_, state) => onboardingRedirect(prefs, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: Routes.cities, builder: (_, _) => const CitiesScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    ],
  );
}
