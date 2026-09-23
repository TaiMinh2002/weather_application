import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/weather_repository_impl.dart';
import '../../domain/entities/weather.dart';

part 'weather_provider.g.dart';

@riverpod
Future<Weather> weather(Ref ref, double lat, double lon) async {
  final result = await ref
      .watch(weatherRepositoryProvider)
      .getWeather(lat: lat, lon: lon);
  return result.getOrThrow();
}
