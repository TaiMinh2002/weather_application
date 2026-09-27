import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../location/domain/entities/place.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/weather.dart';
import '../providers/weather_provider.dart';

/// Hour-by-hour view of one forecast day. Reads the same provider as Home,
/// so coming from Home it renders without a new request.
class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({
    super.key,
    required this.initialDay,
    required this.place,
  });

  final int initialDay;
  final Place place;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  late var _day = widget.initialDay;

  @override
  Widget build(BuildContext context) {
    final provider = weatherProvider(widget.place.lat, widget.place.lon);
    final weather = ref.watch(provider);
    final days = weather.value?.daily ?? const [];
    final day = _day < days.length ? days[_day] : null;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (day != null)
              Text(DateFormat('EEEE, dd/MM', locale).format(day.date)),
            if (widget.place.name case final name?)
              Text(
                name,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
          ],
        ),
      ),
      body: weather.when(
        data: (w) => day == null
            ? const EmptyView()
            : _DayBody(
                weather: w,
                dayIndex: _day,
                onDaySelected: (i) => setState(() => _day = i),
              ),
        loading: () => const _DaySkeleton(),
        error: (e, _) =>
            AppErrorView(error: e, onRetry: () => ref.invalidate(provider)),
      ),
    );
  }
}

class _DaySkeleton extends StatelessWidget {
  const _DaySkeleton();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Skeletonizer.zone(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Row(
            spacing: 8,
            children: [
              for (var i = 0; i < 5; i++)
                Bone(
                  width: 56,
                  height: 48,
                  borderRadius: BorderRadius.circular(999),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Bone(height: 120, borderRadius: radius),
          const SizedBox(height: 20),
          Bone(height: 220, borderRadius: radius),
          const SizedBox(height: 20),
          Bone(height: 180, borderRadius: radius),
        ],
      ),
    );
  }
}

class _DayBody extends ConsumerWidget {
  const _DayBody({
    required this.weather,
    required this.dayIndex,
    required this.onDaySelected,
  });

  final Weather weather;
  final int dayIndex;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final units = ref.watch(settingsProvider).units;
    final day = weather.daily[dayIndex];
    final hours = weather.hoursOn(day.date);
    final now = weather.current.time;
    final isToday = DateUtils.isSameDay(day.date, now);
    final time = DateFormat.Hm(Localizations.localeOf(context).toString());
    // Narrow screens (iPhone SE) get an axis label every 6 hours, not 3.
    final labelEvery = MediaQuery.sizeOf(context).width < 380 ? 6 : 3;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (final (i, d) in weather.daily.indexed)
                _DayChip(
                  weekday: l10n.weekdayShort('${d.date.weekday}'),
                  date: '${d.date.day}',
                  selected: i == dayIndex,
                  onTap: () => onDaySelected(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Card(
          child: Column(
            spacing: 6,
            children: [
              Icon(day.condition.icon(), size: 48),
              Text(day.condition.label(l10n), style: text.titleMedium),
              Text(
                '${units.formatTemp(day.tempMin)} – '
                '${units.formatTemp(day.tempMax)}',
                style: text.titleLarge,
              ),
              Text(
                l10n.rainChance('${day.precipitationProbabilityMax}%'),
                style: text.bodyMedium?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ChartCard(
          title: l10n.temperature,
          height: 170,
          hours: hours,
          labelEvery: labelEvery,
          painter: _TempChartPainter(
            temps: [for (final h in hours) h.temperature],
            label: units.formatTemp,
            line: context.colorScheme.primary,
            grid: context.colorScheme.outline,
            labelStyle: text.labelMedium!.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            // Fraction of the day elapsed, only when showing today.
            now: isToday ? (now.hour + now.minute / 60) / 23 : null,
          ),
        ),
        const SizedBox(height: 20),
        _ChartCard(
          title: l10n.rainChanceTitle,
          height: 120,
          hours: hours,
          labelEvery: labelEvery,
          painter: _RainBarsPainter(
            chances: [for (final h in hours) h.precipitationProbability],
            bar: context.colors.rainy,
            labelStyle: text.labelMedium!.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _StatGrid(
          tiles: [
            _StatTile(
              icon: Symbols.navigation_rounded,
              iconTurns: day.windDirectionDominant / 360,
              label: l10n.maxWind,
              value: units.formatWind(day.windSpeedMax),
              caption: l10n.windFrom(day.windFrom.name),
            ),
            _StatTile(
              icon: Symbols.light_mode_rounded,
              label: l10n.maxUv,
              value: '${day.uvIndexMax.round()}',
              caption: l10n.uvLevel(day.uvLevel.name),
            ),
            _StatTile(
              icon: Symbols.wb_twilight_rounded,
              label: l10n.sunrise,
              value: time.format(day.sunrise),
            ),
            _StatTile(
              icon: Symbols.bedtime_rounded,
              label: l10n.sunset,
              value: time.format(day.sunset),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.weekday,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String weekday;
  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final text = context.textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : context.colors.card,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(weekday, style: text.labelMedium?.copyWith(color: fg)),
                Text(
                  date,
                  style: text.labelLarge?.copyWith(color: fg, height: 16 / 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.height,
    required this.hours,
    required this.labelEvery,
    required this.painter,
  });

  final String title;
  final double height;
  final List<HourlyForecast> hours;
  final int labelEvery;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    final muted = context.textTheme.labelMedium?.copyWith(
      fontSize: 11,
      color: context.colors.textMuted,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(title, style: context.textTheme.titleMedium),
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(painter: painter),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in hours)
                if (h.time.hour % labelEvery == 0)
                  Text(h.time.hour.toString().padLeft(2, '0'), style: muted),
            ],
          ),
        ],
      ),
    );
  }
}

/// Smooth temperature line with a fading fill, value labels every 6 hours
/// and a dashed "now" marker.
class _TempChartPainter extends CustomPainter {
  _TempChartPainter({
    required this.temps,
    required this.label,
    required this.line,
    required this.grid,
    required this.labelStyle,
    this.now,
  });

  final List<double> temps;
  final String Function(double) label;
  final Color line;
  final Color grid;
  final TextStyle labelStyle;

  /// 0–1 position of the current time, or null for other days.
  final double? now;

  @override
  void paint(Canvas canvas, Size size) {
    if (temps.length < 2) return;
    // Room above the line for the value labels.
    const top = 26.0, bottom = 10.0;
    final min = temps.reduce((a, b) => a < b ? a : b) - 1;
    final max = temps.reduce((a, b) => a > b ? a : b) + 1;
    final step = size.width / (temps.length - 1);
    Offset point(int i) => Offset(
      i * step,
      top + (1 - (temps[i] - min) / (max - min)) * (size.height - top - bottom),
    );

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [0.25, 0.5, 0.75]) {
      final y = top + f * (size.height - top - bottom);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < temps.length; i++) {
      final (p0, p1) = (point(i - 1), point(i));
      path.quadraticBezierTo((p0.dx + p1.dx) / 2, p0.dy, p1.dx, p1.dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.35), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    for (final i in {0, 6, 12, 18, temps.length - 1}) {
      if (i >= temps.length) continue;
      final p = point(i);
      final tp = TextPainter(
        text: TextSpan(text: label(temps[i]), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (p.dx - tp.width / 2).clamp(0, size.width - tp.width);
      tp.paint(canvas, Offset(x.toDouble(), p.dy - 8 - tp.height));
    }

    if (now case final now?) {
      final x = now.clamp(0, 1) * size.width;
      final dash = Paint()
        ..color = line
        ..strokeWidth = 1.5;
      for (var y = 10.0; y < size.height - bottom; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 3), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_TempChartPainter old) =>
      old.temps != temps ||
      old.now != now ||
      old.line != line ||
      old.labelStyle != labelStyle;
}

/// One bar per hour; bars of 30 % or more are labelled.
class _RainBarsPainter extends CustomPainter {
  _RainBarsPainter({
    required this.chances,
    required this.bar,
    required this.labelStyle,
  });

  final List<int> chances;
  final Color bar;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (chances.isEmpty) return;
    const labelRoom = 20.0;
    final step = size.width / chances.length;
    final width = step * 0.55;
    final paint = Paint()..color = bar;
    for (final (i, pct) in chances.indexed) {
      final h = pct / 100 * (size.height - labelRoom);
      final x = i * step + (step - width) / 2;
      final rect = Rect.fromLTWH(x, size.height - h, width, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
      if (pct >= 30) {
        final tp = TextPainter(
          text: TextSpan(text: '$pct%', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final lx = (rect.center.dx - tp.width / 2).clamp(
          0,
          size.width - tp.width,
        );
        tp.paint(canvas, Offset(lx.toDouble(), rect.top - 4 - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(_RainBarsPainter old) =>
      old.chances != chances || old.bar != bar;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 16,
    children: [
      for (var i = 0; i < tiles.length; i += 2)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Expanded(child: tiles[i]),
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconTurns = 0,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Clockwise rotation in turns, for the wind arrow.
  final double iconTurns;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final muted = context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 6,
            children: [
              RotationTransition(
                turns: AlwaysStoppedAnimation(iconTurns),
                child: Icon(icon, size: 20),
              ),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: text.labelMedium?.copyWith(
                    color: muted,
                    letterSpacing: 0.36,
                  ),
                ),
              ),
            ],
          ),
          Text(value, style: text.titleLarge),
          if (caption case final caption?)
            Text(caption, style: text.bodyMedium?.copyWith(color: muted)),
        ],
      ),
    );
  }
}
