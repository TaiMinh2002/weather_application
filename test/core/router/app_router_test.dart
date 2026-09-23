import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/core/router/app_router.dart';
import 'package:weather_application/core/storage/prefs.dart';

void main() {
  Future<SharedPreferences> prefs({bool? onboarded}) {
    SharedPreferences.setMockInitialValues({PrefKeys.onboarded: ?onboarded});
    return SharedPreferences.getInstance();
  }

  test('new user is sent to onboarding', () async {
    final p = await prefs();
    expect(onboardingRedirect(p, Routes.home), Routes.onboarding);
    expect(onboardingRedirect(p, Routes.onboarding), isNull);
  });

  test('onboarded user skips onboarding', () async {
    final p = await prefs(onboarded: true);
    expect(onboardingRedirect(p, Routes.home), isNull);
    expect(onboardingRedirect(p, Routes.onboarding), Routes.home);
  });
}
