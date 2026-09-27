import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/city_dto.dart';

part 'cities_remote_ds.g.dart';

class CitiesRemoteDataSource {
  const CitiesRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CityDto>> search(String query, String language) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiConstants.geocodingBaseUrl}/search',
        queryParameters: {'name': query, 'count': 10, 'language': language},
      );
      // The API omits `results` entirely when nothing matches.
      final results = res.data?['results'] as List<dynamic>? ?? const [];
      return [
        for (final r in results) CityDto.fromJson(r as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw e.toAppException();
    }
  }
}

@Riverpod(keepAlive: true)
CitiesRemoteDataSource citiesRemoteDataSource(Ref ref) =>
    CitiesRemoteDataSource(ref.watch(dioProvider));
