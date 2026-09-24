import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weather_application/core/utils/date_formatter.dart';
import 'package:weather_application/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 9, 24, 10, 15); // Thursday
  late AppLocalizations vi;
  late AppLocalizations en;

  setUpAll(() async {
    await initializeDateFormatting();
    vi = await AppLocalizations.delegate.load(const Locale('vi'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('hourLabel', () {
    test('current hour is "now"', () {
      expect(hourLabel(vi, DateTime(2026, 9, 24, 10), now: now), 'Bây giờ');
      expect(hourLabel(en, DateTime(2026, 9, 24, 10), now: now), 'Now');
    });

    test('other hours use 24h clock', () {
      expect(hourLabel(vi, DateTime(2026, 9, 24, 11), now: now), '11:00');
      expect(hourLabel(vi, DateTime(2026, 9, 25, 10), now: now), '10:00');
    });
  });

  group('dayLabel', () {
    test('current date is "today"', () {
      expect(dayLabel(vi, DateTime(2026, 9, 24), now: now), 'Hôm nay');
      expect(dayLabel(en, DateTime(2026, 9, 24), now: now), 'Today');
    });

    test('other dates use the short weekday', () {
      expect(dayLabel(vi, DateTime(2026, 9, 25), now: now), 'Thứ 6');
      expect(dayLabel(en, DateTime(2026, 9, 25), now: now), 'Fri');
    });
  });

  test('timeLabel formats clock time', () {
    expect(timeLabel(vi, DateTime(2026, 9, 24, 5, 48)), '5:48');
    expect(timeLabel(en, DateTime(2026, 9, 24, 5, 48)), '05:48');
  });
}
