# iOS home-screen widget: one-time Xcode setup

The Swift code is ready (`SkycastWidget.swift`), but a Widget Extension target
and an App Group can only be added safely from Xcode.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target… → Widget Extension**. Product name `SkycastWidget`,
   uncheck *Include Live Activity* and *Include Configuration App Intent*.
   When asked to activate the scheme, choose **Cancel**.
3. Xcode creates an `ios/SkycastWidget/` group with a template
   `SkycastWidget.swift` (and maybe `SkycastWidgetBundle.swift`). Replace the
   template with this folder's `SkycastWidget.swift` and delete
   `SkycastWidgetBundle.swift` (this file already has `@main`).
4. Set the extension's **Minimum Deployments** to iOS 17 (for
   `containerBackground`), or lower it and drop that modifier.
5. **Signing & Capabilities → + Capability → App Groups** on *both* the
   `Runner` and `SkycastWidget` targets, with the group
   `group.com.example.weatherApplication` (must match
   `HomeScreenWidget.appGroupId`).
6. Build and run the app once, open Home so it loads the weather, then add the
   widget from the home screen.

Until this is done the app still works; pushing widget data is skipped on iOS.
