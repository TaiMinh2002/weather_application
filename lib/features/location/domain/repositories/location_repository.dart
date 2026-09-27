import '../../../../core/error/errors.dart';
import '../entities/place.dart';

abstract interface class LocationRepository {
  Future<Result<Place>> getCurrentPlace();

  /// Any point (e.g. picked on the map). Never fails: the name is null when
  /// reverse geocoding can't find one.
  Future<Place> placeAt(double lat, double lon);
}
