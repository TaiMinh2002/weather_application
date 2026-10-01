import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// "Offline · updated at 8:15", with the date too once it isn't today.
  String offlineSince(DateTime cachedAt) {
    final locale = Localizations.localeOf(this).toString();
    final sameDay = DateUtils.isSameDay(cachedAt, DateTime.now());
    final time =
        (sameDay ? DateFormat.Hm(locale) : DateFormat.Md(locale).add_Hm())
            .format(cachedAt);
    return l10n.offlineUpdatedAt(time);
  }
}
