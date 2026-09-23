import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_application/core/error/errors.dart';
import 'package:weather_application/core/theme/app_theme.dart';
import 'package:weather_application/core/widgets/state_views.dart';
import 'package:weather_application/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('AppErrorView shows failure message and retry calls back', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      _wrap(
        AppErrorView(error: const NetworkFailure(), onRetry: () => retried++),
      ),
    );

    expect(find.text('Không có kết nối mạng'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retried, 1);
  });

  testWidgets('AppErrorView hides retry button without callback', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AppErrorView(error: 'boom')));

    expect(find.text('Đã có lỗi xảy ra'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
