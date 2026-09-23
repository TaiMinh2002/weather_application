import '../../../../core/error/errors.dart';
import '../entities/place.dart';

abstract interface class LocationRepository {
  Future<Result<Place>> getCurrentPlace();
}
