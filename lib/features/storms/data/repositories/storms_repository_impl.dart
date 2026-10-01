import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/errors.dart';
import '../../domain/entities/storm.dart';
import '../../domain/repositories/storms_repository.dart';
import '../datasources/storms_local_ds.dart';
import '../datasources/storms_remote_ds.dart';
import '../models/storm_dto.dart';

part 'storms_repository_impl.g.dart';

/// Online: fetch and cache. Offline: the last list, each storm marked with
/// [Storm.cachedAt], as long as it's recent enough to still be useful.
/// Neither: the network failure.
class StormsRepositoryImpl implements StormsRepository {
  const StormsRepositoryImpl(this._remote, this._local);

  final StormsRemoteDataSource _remote;
  final StormsLocalDataSource _local;

  /// JMA reissues every 3 to 6 hours and a storm moves hundreds of km a
  /// day; past this an offline track misleads more than it helps.
  static const maxCacheAge = Duration(hours: 12);

  @override
  Future<Result<List<Storm>>> getActiveStorms() => guard(() async {
    try {
      final dtos = await _remote.getActiveStorms();
      await _local.save(dtos, DateTime.now());
      return _entities(dtos);
    } on NetworkException {
      final cached = _local.read();
      if (cached == null) rethrow;
      final (dtos, savedAt) = cached;
      if (DateTime.now().difference(savedAt) > maxCacheAge) rethrow;
      return _entities(dtos, cachedAt: savedAt);
    }
  });

  // A storm whose files no longer parse is dropped, not the whole list.
  static List<Storm> _entities(List<StormDto> dtos, {DateTime? cachedAt}) => [
    for (final d in dtos) ?d.toEntity(cachedAt: cachedAt),
  ];
}

@Riverpod(keepAlive: true)
StormsRepository stormsRepository(Ref ref) => StormsRepositoryImpl(
  ref.watch(stormsRemoteDataSourceProvider),
  ref.watch(stormsLocalDataSourceProvider),
);
