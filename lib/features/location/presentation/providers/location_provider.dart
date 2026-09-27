import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/location_repository_impl.dart';
import '../../domain/entities/place.dart';

part 'location_provider.g.dart';

@riverpod
Future<Place> currentPlace(Ref ref) async =>
    (await ref.watch(locationRepositoryProvider).getCurrentPlace())
        .getOrThrow();

@riverpod
Future<Place> placeAt(Ref ref, double lat, double lon) =>
    ref.watch(locationRepositoryProvider).placeAt(lat, lon);
