import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_screen_widget.g.dart';

/// Pushes text to the native home-screen widgets (Android
/// `SkycastWidgetProvider`, iOS `SkycastWidget` extension), which only draw
/// what they are given.
class HomeScreenWidget {
  const HomeScreenWidget();

  /// Shared with the iOS widget extension; see ios/SkycastWidget/README.md.
  static const appGroupId = 'group.com.minhpt.skycast';

  Future<void> update(Map<String, String> data) async {
    await HomeWidget.setAppGroupId(appGroupId);
    for (final MapEntry(:key, :value) in data.entries) {
      await HomeWidget.saveWidgetData<String>(key, value);
    }
    await HomeWidget.updateWidget(
      androidName: 'SkycastWidgetProvider',
      iOSName: 'SkycastWidget',
    );
    // iOS has one widget in two sizes; Android has a provider per size (and
    // iOS rejects a call without an iOS name).
    if (defaultTargetPlatform == TargetPlatform.android) {
      await HomeWidget.updateWidget(androidName: 'SkycastWidgetMediumProvider');
    }
  }
}

@Riverpod(keepAlive: true)
HomeScreenWidget homeScreenWidget(Ref ref) => const HomeScreenWidget();
