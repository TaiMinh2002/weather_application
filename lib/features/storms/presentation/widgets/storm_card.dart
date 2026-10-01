import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../location/domain/entities/place.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../weather/presentation/widgets/forecast_cards.dart';
import '../../domain/entities/storm.dart';
import '../providers/storms_provider.dart';

/// "Bão mạnh Surigae", or just the class while the storm is unnamed.
String stormTitle(AppLocalizations l10n, Storm storm, StormPoint point) {
  final kind = switch (StormStrength.of(point.windMs)) {
    final s? => l10n.stormStrength(s.name),
    null => l10n.stormStrength(StormStrength.depression.name),
  };
  return [kind, ?storm.name].join(' ');
}

/// "Gió cấp 10 (90 km/h), giật cấp 12"; null without a wind figure.
String? stormWind(AppLocalizations l10n, Units units, StormPoint point) {
  final ms = point.windMs;
  if (ms == null) return null;
  final speed = units.formatWind(ms * 3.6);
  return switch (point.gustMs) {
    final g? => l10n.stormWind(beaufort(ms), speed, beaufort(g)),
    null => l10n.stormWindNoGust(beaufort(ms), speed),
  };
}

/// The nearest storm that is, or will come, within reach of [place]. Like
/// the air-quality card it's extra information, so loading, errors and
/// quiet seasons all simply leave it out.
class StormCard extends ConsumerWidget {
  const StormCard({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storms = ref.watch(activeStormsProvider).value ?? const [];
    final storm = stormsNear(storms, place.lat, place.lon).firstOrNull;
    if (storm == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final text = context.textTheme;
    final units = ref.watch(settingsProvider.select((s) => s.units));
    final now = storm.now;
    final nowKm = distanceKm(now.lat, now.lon, place.lat, place.lon);
    final closest = closestApproach(storm, place.lat, place.lon);
    final distance = [
      l10n.stormDistance(nowKm.round()),
      if (closest.point.hoursAhead > 0 && closest.km < nowKm - 50)
        l10n.stormClosest(closest.km.round(), closest.point.hoursAhead),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => context.push(Routes.stormOf(storm.id, place)),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 12,
            children: [
              const Icon(Symbols.cyclone_rounded, size: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      l10n.stormWatch.toUpperCase(),
                      style: text.labelMedium?.copyWith(letterSpacing: 0.36),
                    ),
                    Text(stormTitle(l10n, storm, now), style: text.titleMedium),
                    if (stormWind(l10n, units, now) case final wind?)
                      Text(wind, style: text.bodyMedium),
                    Opacity(
                      opacity: 0.85,
                      child: Text(distance, style: text.bodyMedium),
                    ),
                  ],
                ),
              ),
              const Icon(Symbols.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
