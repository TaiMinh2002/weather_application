# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Skycast: a Flutter weather app using the free Open-Meteo API (no API key needed). Done so far: base code in `lib/core/`, the `weather` data layer with offline cache, the `location` feature (GPS + reverse geocoding), onboarding, the Home screen (GPS page + one page per saved city), the Cities screen (search + saved list + a `/map` picker on OpenStreetMap via flutter_map; map picks become `City.fromPlace` with a negative id, `features/cities/`), and Settings (`settingsProvider`: units, theme, language, stored in shared_preferences). Day Detail (`/day/:index?lat=&lon=&name=`, build links with `Routes.dayOf`; charts are `CustomPainter`s) is built too. Onboarding follows the design, and the native splash + app icon are drawn from the design's glyph: Android uses vector drawables (`res/drawable/splash_icon.xml`, `android12_splash.xml`, `ic_launcher_foreground.xml`; colors in `values(-night)/colors.xml`), iOS uses an SVG launch image with a dark variant and a `LaunchBackground` named color. Home also has a tips card (rule-based `tipsFor` in `weather.dart`; add rules there, with tests) and an air-quality card (`airQualityProvider`, separate from the forecast so its failure only hides the card; not cached). Home also shows a 2-hour rain nowcast card (`rainOutlook`, hidden for offline data) A share button next to the place name opens a preview of a 4:5 share image (`features/share/`: `ShareCard` captured through a `RepaintBoundary`, sent with `share_plus`). Home also has an activities card (`features/activities/`: hour-by-hour `scoreAt` rules and `bestWindow`; picks live in `settingsProvider.activities`, edited from the card; tune rules there, with tests). Saved cities are backed up to Supabase (`cities_sync_ds.dart`, table in `supabase/schema.sql`) via a silent anonymous sign-in; the device list stays the source of truth and sync failures are logged, never shown. Keys come from `--dart-define` (`ApiConstants.hasSupabase`), so builds without them just skip sync. Push weather alerts (`features/alerts/`) work the same way: the app upserts an `alert_subscriptions` row (FCM token, GPS place, chosen `AlertType`s) with each fresh GPS forecast, and the `supabase/functions/check-alerts` Edge Function (pg_cron hourly; pure rules in `rules.ts`, tested with `deno test`) decides and sends via FCM HTTP v1. Firebase options also come from `--dart-define` (`ApiConstants.hasFirebase`, no google-services.json/plist), so builds without them hide the switch; setup steps are in that function's README. Morning notifications (`features/notifications/`): when the setting is on, each fresh GPS forecast on Home re-schedules the next 7 mornings at 7:00 (`morningSlots`), each carrying its own day's forecast, so no background work is needed. The home-screen widget (`features/home_widget/`) gets pre-formatted text from the same Home listener (`widgetData`); Android draws it in `SkycastWidgetProvider.kt` with `widget_bg_<sky>` drawables, iOS in the `SkycastWidget` extension target (`ios/SkycastWidget/`, iOS 17+, App Group `group.com.minhpt.skycast` in both entitlements files; see its README). Sky colours live in `Sky` (app_theme.dart); keep the native copies in sync. Format temperatures and wind with `settingsProvider.units` (`core/utils/unit_converter.dart`), never by hand. Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) are gitignored, so run `flutter gen-l10n` + `build_runner` after cloning.

`// ponytail:` comments mark deliberate shortcuts and say which later step replaces them. Grep for them before building the feature they mention.

Design docs (Vietnamese):

- `plan.md`: features, screens, packages, API endpoints, target architecture, and the 2-week roadmap (the "day N" references in code). Read it before building a feature.
- `rule.md`: coding rules. **Follow it strictly.** The user wrote these rules; they aren't generic advice.

## Commands

```bash
flutter pub get
flutter gen-l10n                                           # after editing .arb files (template: app_en.arb)
dart run build_runner build --delete-conflicting-outputs   # after editing freezed / json / @riverpod code
flutter analyze                                            # must be warning-free before commit
flutter test                                               # all tests
flutter test test/path/to_test.dart                        # single file
flutter test --plain-name "test name"                      # single test by name
flutter run
flutter test tool/screenshots_test.dart --update-goldens    # regenerate README screenshots (docs/screenshots/)
flutter run --dart-define-from-file=supabase.json           # with cloud backup (supabase.json is gitignored)
```

CI (`.github/workflows/ci.yml`) runs analyze + test + release APK on pushes/PRs to `dev`/`main`, plus a `server` job that runs `deno test` and `deno check` for the check-alerts Edge Function; pushing a `v*` tag also publishes a GitHub Release with the APK.

Lint uses `flutter_lints` (see `analysis_options.yaml`; platform folders are excluded).

## Key rules (from rule.md)

- **File size limit: 600 lines** (generated files don't count). Under 600 lines, **don't split a file** unless code is reused elsewhere. Private sub-widgets (`_Foo`) stay in the file of the screen that uses them. No barrel files, no single-constant files.
- Only create folders when a real file goes into them. Don't scaffold empty directories.
- Abstract interfaces only for repositories (in `domain/`, so tests can mock them). Don't add interfaces for anything else that has one implementation.
- Colors and text styles come from `Theme` / `ThemeExtension` (e.g. `context.colors.textMuted`, `context.textTheme`). UI strings come from `context.l10n` (`.arb`, vi + en). Never hard-code either.
- Every data screen handles loading (skeleton), error (`AppErrorView` with retry), and empty.
- No silent `catch (_) {}`: a swallowed error needs a comment explaining why. No dead or commented-out code, no `print()`. Comments explain *why*, not *what*.
- Don't add a package when a few lines of code would do.
- Pure logic (mappers, converters, repositories) needs unit tests; shared widgets need widget tests. Mock with `mocktail`.
- Conventional Commits. Branch `feature/<name>` off `dev` and open PRs into `dev` (not `main`); `dev` is merged to `main` when stable.

## Architecture

Feature-first clean architecture: `lib/core/` + `lib/features/<feature>/{data,domain,presentation}`. **There is no usecase layer**: Riverpod providers (codegen `@riverpod`) call repositories directly.

Providers live next to what they build: each datasource and repository impl file ends with its own `@Riverpod(keepAlive: true)` provider (e.g. `weatherRepositoryProvider` is in `weather_repository_impl.dart`). Presentation providers in `presentation/providers/` are auto-dispose and take params (e.g. `weatherProvider(lat, lon)`).

`sharedPreferencesProvider` (`core/storage/prefs.dart`) throws until it's overridden. `main.dart` loads `SharedPreferences` and injects it with `overrideWithValue`, so any test that touches it must override it the same way.

### Error flow (`core/error/errors.dart`)

1. Datasource catches `DioException` and throws `e.toAppException()` (from `core/network/dio_client.dart`), which gives `NetworkException` or `ServerException`. Location code throws `LocationException(LocationError.x)`.
2. Repository wraps its body in `guard(() async { ... })`, which catches any exception and returns `Result<T>` (`Ok` / `Err`). `toFailure` maps exceptions to the `sealed class Failure` types (`NetworkFailure`, `ServerFailure`, `CacheFailure`, `LocationFailure`, `UnknownFailure`).
3. The presentation provider calls `result.getOrThrow()`, so the `Failure` lands in `AsyncValue.error`.
4. UI uses `ref.watch(provider).when(data/loading/error)` and passes the error to `AppErrorView` (`core/widgets/state_views.dart`). `AppErrorView` switches on the `Failure` type to pick the icon and l10n message. When you add a new `Failure` or `LocationError`, update `toFailure` and `AppErrorView` too.

Failures carry no message strings; messages are resolved through l10n in the UI.

### Data policy

When online, call the API and write the result to the cache (`weather_local_ds.dart`: JSON in shared_preferences, keyed by lat/lon rounded to 2 decimals). On `NetworkException`, return the cache with `Weather.cachedAt` set (Home shows the offline banner). No cache, or any other error: return the `Failure`.

### Other conventions

- Network: a single Dio provider in `core/network/dio_client.dart`. **Don't write custom interceptors.** Only add Dio's `LogInterceptor`, and only in debug mode.
- Models: API DTOs use freezed + json_serializable with a `Dto` suffix and a `toEntity()` method. Domain entities are plain classes.
- Router: `go_router` in `core/router/app_router.dart`. Route paths are constants in `Routes`. The `redirect` uses the pure function `onboardingRedirect`, which reads the `onboarded` flag from shared_preferences, so it's unit-testable.
- Open-Meteo returns WMO `weather_code`. `core/utils/weather_code_mapper.dart` maps it to the `WeatherCondition` enum (label, icon, color) and has unit tests.
- Avoid paid services: no Google Maps (it requires billing). Use `flutter_map` + OpenStreetMap instead.
