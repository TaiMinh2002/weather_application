# iOS home-screen widget

The `SkycastWidget` Widget Extension target is part of `Runner.xcodeproj`
(iOS 17+, embedded into the app by Runner's *Embed Foundation Extensions*
phase, which sits before *Thin Binary* to avoid Xcode's build-cycle error).

- `SkycastWidget.swift`: the widget (SwiftUI + WidgetKit). It reads the text the
  Flutter app writes (`lib/features/home_widget/`) from the App Group and only
  draws it. Sky colours mirror `Sky` in `lib/core/theme/app_theme.dart`.
- `Info.plist`, `SkycastWidget.entitlements`: extension metadata and the App
  Group `group.com.example.weatherApplication`. `Runner/Runner.entitlements`
  has the same group (must match `HomeScreenWidget.appGroupId`).

## Running on a real iPhone

The simulator needs nothing extra. On a device, the App Group has to be
registered with your Apple developer team once:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. For both the **Runner** and **SkycastWidget** targets, open
   **Signing & Capabilities**, keep *Automatically manage signing* on and pick
   your team. Xcode registers the App Group and the
   `com.example.weatherApplication.SkycastWidget` bundle id.
3. Run once from Xcode (or `flutter run`), open Home so it loads the weather,
   then add the widget from the home screen.

If you change the app's bundle id, change the widget's to
`<app bundle id>.SkycastWidget`, and update the App Group in both entitlements
files and `HomeScreenWidget.appGroupId`.
