import '../../../../core/error/errors.dart';
import '../entities/city.dart';

abstract interface class CitiesRepository {
  Future<Result<List<City>>> search(String query);

  List<City> savedCities();

  Future<void> saveCities(List<City> cities);

  /// Once per launch: restores the cloud backup when this device has no
  /// saved cities (returns them), otherwise backs up the local list (null).
  Future<List<City>?> syncOnStart();
}
