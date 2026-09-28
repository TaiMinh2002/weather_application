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
  }
}

@Riverpod(keepAlive: true)
HomeScreenWidget homeScreenWidget(Ref ref) => const HomeScreenWidget();
