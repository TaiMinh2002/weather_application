import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../models/storm_dto.dart';

part 'storms_remote_ds.g.dart';

/// Active tropical cyclones from JMA. Free to reuse with attribution
/// (JMA's Public Data License, CC BY 4.0 compatible); the storm screen
/// credits it.
class StormsRemoteDataSource {
  const StormsRemoteDataSource(this._dio);

  final Dio _dio;

  static const _base = 'https://www.jma.go.jp/bosai/typhoon/data';

  Future<List<StormDto>> getActiveStorms() async {
    try {
      final list = await _get<List<dynamic>>('$_base/targetTc.json');
      final ids = [
        for (final t in list.cast<Map<String, dynamic>>())
          if (t['tropicalCyclone'] case final String id) id,
      ];
      return await Future.wait([
        for (final id in ids)
          Future.wait([
            _get<List<dynamic>>('$_base/$id/specifications.json'),
            _get<List<dynamic>>('$_base/$id/forecast.json'),
          ]).then(
            (files) => StormDto(
              id: id,
              specs: files[0].cast<Map<String, dynamic>>(),
              forecast: files[1].cast<Map<String, dynamic>>(),
            ),
          ),
      ]);
    } on DioException catch (e) {
      throw e.toAppException();
    }
  }

  Future<T> _get<T>(String url) async => (await _dio.get<T>(url)).data as T;
}

@Riverpod(keepAlive: true)
StormsRemoteDataSource stormsRemoteDataSource(Ref ref) =>
    StormsRemoteDataSource(ref.watch(dioProvider));
