import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/api_constants.dart';
import '../error/errors.dart';

part 'dio_client.g.dart';

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.forecastBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  if (kDebugMode) dio.interceptors.add(LogInterceptor(responseBody: true));
  return dio;
}

/// Use in datasources: `on DioException catch (e) { throw e.toAppException(); }`
extension DioExceptionX on DioException {
  AppException toAppException() => switch (type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(),
    _ => ServerException(response?.statusCode),
  };
}
