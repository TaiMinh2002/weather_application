import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

// `now` is the forecast location's current time (`Weather.current.time`),
// not the device clock: a saved city may be in another timezone.

/// "Now" for the current hour, otherwise the locale clock time ("11:00").
String hourLabel(
  AppLocalizations l10n,
  DateTime time, {
  required DateTime now,
}) => _sameDay(time, now) && time.hour == now.hour
    ? l10n.now
    : DateFormat.Hm(l10n.localeName).format(time);

/// "Today" for the current date, otherwise the short weekday ("Thứ 5", "Thu").
String dayLabel(
  AppLocalizations l10n,
  DateTime date, {
  required DateTime now,
}) => _sameDay(date, now)
    ? l10n.today
    : DateFormat.E(l10n.localeName).format(date);

/// Clock time for sunrise, sunset and "updated at": "5:48" (vi), "05:48" (en).
String timeLabel(AppLocalizations l10n, DateTime time) =>
    DateFormat.Hm(l10n.localeName).format(time);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
