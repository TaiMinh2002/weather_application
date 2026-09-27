import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/city.dart';

part 'city_dto.freezed.dart';
part 'city_dto.g.dart';

/// One item of the geocoding `/search` `results`; also the stored shape of a
/// saved city.
@freezed
abstract class CityDto with _$CityDto {
  const CityDto._();

  const factory CityDto({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    String? admin1,
    String? country,
  }) = _CityDto;

  factory CityDto.fromJson(Map<String, dynamic> json) =>
      _$CityDtoFromJson(json);

  factory CityDto.fromEntity(City city) => CityDto(
    id: city.id,
    name: city.name,
    latitude: city.lat,
    longitude: city.lon,
    admin1: city.region,
    country: city.country,
  );

  City toEntity() => City(
    id: id,
    name: name,
    lat: latitude,
    lon: longitude,
    region: admin1,
    country: country,
  );
}
