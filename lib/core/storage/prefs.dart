import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs.g.dart';

abstract final class PrefKeys {
  static const onboarded = 'onboarded';
}

/// Loaded once in `main()` and injected via `overrideWithValue`.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('Override sharedPreferencesProvider in main()');
