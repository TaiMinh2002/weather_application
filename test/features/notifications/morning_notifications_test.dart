import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:weather_application/core/storage/prefs.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/features/notifications/data/morning_notifications.dart';
import 'package:weather_application/features/settings/presentation/providers/settings_provider.dart';
import 'package:weather_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:weather_application/l10n/app_localizations.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockNotifications extends Mock implements MorningNotifications {}

void main() {
  final week = [for (var d = 0; d < 7; d++) DateTime(2026, 9, 26 + d)];

  test('morningSlots skips a morning that has already passed', () {
    final after = morningSlots(week, DateTime(2026, 9, 26, 8));
    expect(after.length, 6);
    expect(after.first, (at: DateTime(2026, 9, 27, 7), day: 1));

    final before = morningSlots(week, DateTime(2026, 9, 26, 6, 59));
    expect(before.first, (at: DateTime(2026, 9, 26, 7), day: 0));
    expect(before.length, 7);
  });

  test('morningSlots fires at the chosen time, half hours included', () {
    final slots = morningSlots(
      week,
      DateTime(2026, 9, 26, 6),
      minutes: 6 * 60 + 30,
    );
    expect(slots.first, (at: DateTime(2026, 9, 26, 6, 30), day: 0));
    expect(
      morningSlots(week, DateTime(2026, 9, 26, 9), minutes: 9 * 60).first.day,
      1,
    );
  });

  test('schedule clears the old week, then arms one id per morning', () async {
    final plugin = _MockPlugin();
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(tz.TZDateTime.utc(2026));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) async => true);
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});

    final at = DateTime(2026, 9, 27, 7);
    await MorningNotifications(plugin).schedule([
      (at: at, title: 'Hà Nội hôm nay', body: 'Mưa rào · 25° – 30°'),
    ], channelName: 'Dự báo buổi sáng');

    verify(() => plugin.cancel(id: any(named: 'id'))).called(7);
    final scheduled =
        verify(
              () => plugin.zonedSchedule(
                id: 700,
                scheduledDate: captureAny(named: 'scheduledDate'),
                notificationDetails: any(named: 'notificationDetails'),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                title: 'Hà Nội hôm nay',
                body: 'Mưa rào · 25° – 30°',
              ),
            ).captured.single
            as tz.TZDateTime;
    expect(scheduled.isAtSameMomentAs(at), isTrue);
  });

  group('Settings toggle', () {
    late SharedPreferences prefs;
    late _MockNotifications notifications;

    Future<ProviderContainer> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      notifications = _MockNotifications();
      when(notifications.cancel).thenAnswer((_) async {});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          morningNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      return container;
    }

    testWidgets('granted permission turns it on and persists', (tester) async {
      final container = await pump(tester);
      when(notifications.requestPermission).thenAnswer((_) async => true);

      // Below the health group, so off the test viewport at first.
      await tester.scrollUntilVisible(find.byType(Switch), 200);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).morningForecast, isTrue);
      expect(prefs.getBool(PrefKeys.morningForecast), isTrue);
    });

    testWidgets('once on, the time can be changed and is kept', (tester) async {
      final container = await pump(tester);
      when(notifications.requestPermission).thenAnswer((_) async => true);
      expect(find.text('Giờ nhận'), findsNothing);

      await tester.scrollUntilVisible(find.byType(Switch), 200);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Giờ nhận'), 100);
      await tester.tap(find.text('7:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6:30').last);
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).morningMinutes, 6 * 60 + 30);
      expect(prefs.getInt(PrefKeys.morningMinutes), 6 * 60 + 30);
    });

    testWidgets('denied permission keeps it off and explains', (tester) async {
      final container = await pump(tester);
      when(notifications.requestPermission).thenAnswer((_) async => false);

      // Below the health group, so off the test viewport at first.
      await tester.scrollUntilVisible(find.byType(Switch), 200);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).morningForecast, isFalse);
      expect(
        find.text(
          'Skycast chưa được phép gửi thông báo. '
          'Bật lại trong Cài đặt của máy.',
        ),
        findsOneWidget,
      );
    });
  });
}
