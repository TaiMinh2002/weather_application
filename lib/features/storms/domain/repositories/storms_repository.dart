import '../../../../core/error/errors.dart';
import '../entities/storm.dart';

abstract interface class StormsRepository {
  /// Every tropical cyclone JMA is tracking now; empty most of the year.
  Future<Result<List<Storm>>> getActiveStorms();
}
