# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Skycast: a Flutter weather app using the free Open-Meteo API (no API key needed). Done so far: base code in `lib/core/`, the `weather` data layer (remote only), the `location` feature (GPS + reverse geocoding), and onboarding. `HomeScreen` is a minimal view that proves the data layer, not the real Home UI. Hive caching, city search, saved cities, and settings are not built yet. Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) are gitignored, so run `flutter gen-l10n` + `build_runner` after cloning.

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
```

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

### Data policy (target, per plan.md)

When online, call the API and write the result to the Hive cache. When offline, return the cache plus its "updated at" time. If there's neither network nor cache, return `Failure`. The weather repository is remote-only for now (Hive isn't in `pubspec.yaml` yet).

### Other conventions

- Network: a single Dio provider in `core/network/dio_client.dart`. **Don't write custom interceptors.** Only add Dio's `LogInterceptor`, and only in debug mode.
- Models: API DTOs use freezed + json_serializable with a `Dto` suffix and a `toEntity()` method. Domain entities are plain classes.
- Router: `go_router` in `core/router/app_router.dart`. Route paths are constants in `Routes`. The `redirect` uses the pure function `onboardingRedirect`, which reads the `onboarded` flag from shared_preferences, so it's unit-testable.
- Open-Meteo returns WMO `weather_code`. `core/utils/weather_code_mapper.dart` maps it to the `WeatherCondition` enum (label, icon, color) and has unit tests.
- Avoid paid services: no Google Maps (it requires billing). Use `flutter_map` + OpenStreetMap instead.
