abstract final class ApiConstants {
  static const forecastBaseUrl = 'https://api.open-meteo.com/v1';
  static const geocodingBaseUrl = 'https://geocoding-api.open-meteo.com/v1';
  static const airQualityBaseUrl = 'https://air-quality-api.open-meteo.com/v1';

  /// From `--dart-define-from-file=supabase.json` (gitignored; see
  /// supabase.example.json). Empty means cloud backup is off.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const hasSupabase = supabaseUrl != '' && supabaseAnonKey != '';
}
