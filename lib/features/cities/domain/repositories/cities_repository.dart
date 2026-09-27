import '../../../../core/error/errors.dart';
import '../entities/city.dart';

abstract interface class CitiesRepository {
  Future<Result<List<City>>> search(String query);

  List<City> savedCities();

  Future<void> saveCities(List<City> cities);
}
