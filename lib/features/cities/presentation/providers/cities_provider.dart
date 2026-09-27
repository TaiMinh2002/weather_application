import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/cities_repository_impl.dart';
import '../../domain/entities/city.dart';

part 'cities_provider.g.dart';

/// Saved cities in the user's order. Home builds one page per entry.
@Riverpod(keepAlive: true)
class SavedCities extends _$SavedCities {
  @override
  List<City> build() => ref.watch(citiesRepositoryProvider).savedCities();

  Future<void> add(City city) async {
    if (state.any((c) => c.id == city.id)) return;
    await _set([...state, city]);
  }

  /// Puts [city] back at [index], for undoing a delete.
  Future<void> insert(int index, City city) =>
      _set([...state]..insert(index.clamp(0, state.length), city));

  Future<void> remove(City city) =>
      _set([...state.where((c) => c.id != city.id)]);

  /// [to] is the final index of the moved city.
  Future<void> move(int from, int to) {
    final cities = [...state];
    cities.insert(to, cities.removeAt(from));
    return _set(cities);
  }

  Future<void> _set(List<City> cities) {
    state = cities;
    return ref.read(citiesRepositoryProvider).saveCities(cities);
  }
}

const searchDebounce = Duration(milliseconds: 400);

/// Waits [searchDebounce] first: each keystroke makes a new query, which
/// disposes the previous one, so only the last query reaches the API.
@riverpod
Future<List<City>> citySearch(Ref ref, String query) async {
  await Future<void>.delayed(searchDebounce);
  if (!ref.mounted) return const [];
  final result = await ref.read(citiesRepositoryProvider).search(query);
  return result.getOrThrow();
}
