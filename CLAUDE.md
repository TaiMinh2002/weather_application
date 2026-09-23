# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Skycast: a Flutter weather app using the free Open-Meteo API (no API key needed). Base code in `lib/core/` is done (Dio, errors/Result, theme, router, l10n, shared widgets); features are not built yet (`HomeScreen` is a placeholder). Generated files (`*.g.dart`, `lib/l10n/app_localizations*.dart`) are gitignored, so run `flutter gen-l10n` + `build_runner` after cloning. The design lives in docs:

- `plan.md`: features, screens, packages, API endpoints, target architecture, and a 2-week roadmap. Read it before building a feature.
- `rule.md`: coding rules. **Follow it strictly.** The user wrote these rules; they aren't generic advice.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after editing freezed / json / @riverpod code
flutter analyze                                            # must be warning-free before commit
flutter test                                               # all tests
flutter test test/path/to_test.dart                        # single file
flutter test --plain-name "test name"                      # single test by name
flutter run
```

Lint uses `flutter_lints` (see `analysis_options.yaml`; platform folders are excluded).

## Key rules (from rule.md)

- **File size limit: 600 lines** (generated `*.g.dart` / `*.freezed.dart` don't count). Under 600 lines, **don't split a file** unless code is reused elsewhere. Private sub-widgets (`_Foo`) stay in the file of the screen that uses them. No barrel files, no single-constant files.
- Only create folders when a real file goes into them. Don't scaffold empty directories.
- Colors and text styles come from `Theme` / `ThemeExtension`. UI strings come from `context.l10n` (`.arb`, vi + en). Never hard-code either.
- Every data screen handles loading (skeleton), error (`AppErrorView` with retry), and empty.
- Conventional Commits. Work on `feature/<name>` branches and open PRs into `main`.

## Target architecture (from plan.md §5–6)

Feature-first clean architecture: `lib/core/` + `lib/features/<feature>/{data,domain,presentation}`. **There is no usecase layer**: Riverpod providers (codegen `@riverpod`) call repositories directly.

Error flow crosses three layers:
1. Datasource catches `DioException` and throws an app exception (`NetworkException` / `ServerException`).
2. Repository catches the exception and returns `Result<T>`, which holds a `sealed class Failure` (`NetworkFailure`, `ServerFailure`, `CacheFailure`, `LocationFailure`).
3. UI uses `ref.watch(provider).when(data/loading/error)`.

Repository data policy: when online, call the API and write the result to the Hive cache. When offline, return the cache plus its "updated at" time. If there's neither network nor cache, return `Failure`.

Network: a single `createDio()` in `core/network/`. **Don't write custom interceptors.** Only add Dio's `LogInterceptor`, and only in debug mode.

Router: `go_router` with a `redirect` that sends users who haven't onboarded yet to `/onboarding`, based on the `onboarded` flag in shared_preferences.

Open-Meteo returns WMO `weather_code`. Map it to a description, icon, and color in `core/utils/weather_code_mapper.dart`, and unit-test that mapper.

Avoid paid services: no Google Maps (it requires billing). Use `flutter_map` + OpenStreetMap instead.
