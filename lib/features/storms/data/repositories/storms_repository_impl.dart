import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';
import '../../domain/entities/storm.dart';
import '../../domain/repositories/storms_repository.dart';
import '../datasources/storms_remote_ds.dart';

part 'storms_repository_impl.g.dart';

// ponytail: not cached; offline just hides the storm card. A storm is the one
// thing worth showing offline, so cache the last list if that comes up.
class StormsRepositoryImpl implements StormsRepository {
  const StormsRepositoryImpl(this._remote);

  final StormsRemoteDataSource _remote;

  @override
  Future<Result<List<Storm>>> getActiveStorms() => guard(() async {
    final dtos = await _remote.getActiveStorms();
    // A storm whose files no longer parse is dropped, not the whole list.
    return [for (final d in dtos) ?d.toEntity()];
  });
}

@Riverpod(keepAlive: true)
StormsRepository stormsRepository(Ref ref) =>
    StormsRepositoryImpl(ref.watch(stormsRemoteDataSourceProvider));
