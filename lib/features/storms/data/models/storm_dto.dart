import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/storm.dart';

part 'storm_dto.freezed.dart';
part 'storm_dto.g.dart';

// JMA's typhoon JSON (jma.go.jp/bosai/typhoon/data/) powers its own site and
// has no published schema: each file is a list of differently shaped
// "parts". Only the fields Skycast shows are read, and each through a
// nullable path, so a new or renamed field hides a value instead of failing
// the whole storm.

Object? _at(Map<dynamic, dynamic> json, List<String> path) {
  Object? v = json;
  for (final key in path) {
    if (v is! Map) return null;
    v = v[key];
  }
  return v;
}

Object? _utc(Map<dynamic, dynamic> j, String _) => _at(j, ['validtime', 'UTC']);
Object? _issue(Map<dynamic, dynamic> j, String _) => _at(j, ['issue', 'UTC']);
Object? _deg(Map<dynamic, dynamic> j, String _) => _at(j, ['position', 'deg']);
Object? _nameEn(Map<dynamic, dynamic> j, String _) => _at(j, ['name', 'en']);
Object? _categoryEn(Map<dynamic, dynamic> j, String _) =>
    _at(j, ['category', 'en']);
Object? _wind(Map<dynamic, dynamic> j, String _) =>
    _at(j, ['maximumWind', 'sustained', 'm/s']);
Object? _gust(Map<dynamic, dynamic> j, String _) =>
    _at(j, ['maximumWind', 'gust', 'm/s']);
Object? _radius(Map<dynamic, dynamic> j, String _) =>
    _at(j, ['probabilityCircleRadius', 'km']);
Object? _pastTrack(Map<dynamic, dynamic> j, String _) => [
  ...?_at(j, ['track', 'preTyphoon']) as List?,
  ...?_at(j, ['track', 'typhoon']) as List?,
];

/// One part of `specifications.json`: the title (name, issue time) or the
/// analysis / a forecast time.
@freezed
abstract class JmaSpecDto with _$JmaSpecDto {
  const factory JmaSpecDto({
    int? advancedHours,
    @JsonKey(readValue: _utc) String? validTime,
    @JsonKey(readValue: _issue) String? issue,
    @JsonKey(readValue: _nameEn) String? name,
    @JsonKey(readValue: _categoryEn) String? category,
    @JsonKey(readValue: _deg) List<num>? position,
    // Strings in JMA's JSON ("18"), sometimes "-".
    @JsonKey(readValue: _wind) Object? windMs,
    @JsonKey(readValue: _gust) Object? gustMs,
    Object? pressure,
    @JsonKey(readValue: _radius) num? radiusKm,
  }) = _JmaSpecDto;

  factory JmaSpecDto.fromJson(Map<String, dynamic> json) =>
      _$JmaSpecDtoFromJson(json);
}

/// One part of `forecast.json`; only the analysis carries the past track.
@freezed
abstract class JmaForecastDto with _$JmaForecastDto {
  const factory JmaForecastDto({
    @JsonKey(readValue: _pastTrack) @Default([]) List<List<num>> track,
  }) = _JmaForecastDto;

  factory JmaForecastDto.fromJson(Map<String, dynamic> json) =>
      _$JmaForecastDtoFromJson(json);
}

/// One storm from its two JMA files.
@freezed
abstract class StormDto with _$StormDto {
  const StormDto._();

  const factory StormDto({
    required String id,
    required List<JmaSpecDto> specs,
    required List<JmaForecastDto> forecast,
  }) = _StormDto;

  /// Null when JMA's files hold no usable position, i.e. the format moved.
  Storm? toEntity() {
    final title = specs.firstOrNull;
    final points = [
      for (final s in specs.skip(1))
        if ((s.position, s.validTime, s.advancedHours) case (
          [final lat, final lon, ...],
          final time?,
          final hours?,
        ))
          StormPoint(
            time: DateTime.parse(time),
            hoursAhead: hours,
            lat: lat.toDouble(),
            lon: lon.toDouble(),
            windMs: _number(s.windMs),
            gustMs: _number(s.gustMs),
            pressure: _number(s.pressure)?.round(),
            radiusKm: s.radiusKm?.toDouble(),
            isLow: s.category == 'LOW',
          ),
    ];
    if (points.isEmpty) return null;
    return Storm(
      id: id,
      name: title?.name,
      issuedAt: DateTime.tryParse(title?.issue ?? '') ?? points.first.time,
      points: points,
      track: [
        for (final part in forecast)
          for (final p in part.track)
            if (p case [final lat, final lon, ...])
              (lat: lat.toDouble(), lon: lon.toDouble()),
      ],
    );
  }

  static double? _number(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
}
