import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/storms_repository_impl.dart';
import '../../domain/entities/storm.dart';

part 'storms_provider.g.dart';

@riverpod
Future<List<Storm>> activeStorms(Ref ref) async {
  final result = await ref.watch(stormsRepositoryProvider).getActiveStorms();
  return result.getOrThrow();
}
