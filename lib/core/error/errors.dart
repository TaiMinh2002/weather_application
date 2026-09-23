/// Exceptions are thrown by datasources, then converted to [Failure] in the
/// repository so the UI only ever deals with [Result] / [Failure].
sealed class AppException implements Exception {
  const AppException();
}

class NetworkException extends AppException {
  const NetworkException();
}

class ServerException extends AppException {
  const ServerException([this.statusCode]);
  final int? statusCode;
}

class CacheException extends AppException {
  const CacheException();
}

enum LocationError { serviceDisabled, denied, deniedForever, unavailable }

class LocationException extends AppException {
  const LocationException(this.reason);
  final LocationError reason;
}

/// Messages are resolved via l10n in `AppErrorView`, not stored here.
sealed class Failure {
  const Failure();
}

class NetworkFailure extends Failure {
  const NetworkFailure();
}

class ServerFailure extends Failure {
  const ServerFailure();
}

class CacheFailure extends Failure {
  const CacheFailure();
}

class LocationFailure extends Failure {
  const LocationFailure(this.reason);
  final LocationError reason;
}

class UnknownFailure extends Failure {
  const UnknownFailure(this.error);
  final Object error;
}

sealed class Result<T> {
  const Result();

  /// For Riverpod providers: a thrown [Failure] lands in `AsyncValue.error`.
  T getOrThrow() => switch (this) {
    Ok(:final data) => data,
    Err(:final failure) => throw failure,
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

Failure toFailure(Object error) => switch (error) {
  NetworkException() => const NetworkFailure(),
  ServerException() => const ServerFailure(),
  CacheException() => const CacheFailure(),
  LocationException(:final reason) => LocationFailure(reason),
  _ => UnknownFailure(error),
};

/// Wrap repository calls: `return guard(() => _remote.getForecast(lat, lon));`
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } catch (e) {
    return Err(toFailure(e));
  }
}
