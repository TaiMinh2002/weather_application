abstract final class ApiConstants {
  static const forecastBaseUrl = 'https://api.open-meteo.com/v1';
  static const geocodingBaseUrl = 'https://geocoding-api.open-meteo.com/v1';
  static const airQualityBaseUrl = 'https://air-quality-api.open-meteo.com/v1';

  /// From `--dart-define-from-file=supabase.json` (gitignored; see
  /// supabase.example.json). Empty means cloud backup is off.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const hasSupabase = supabaseUrl != '' && supabaseAnonKey != '';

  /// Also from the define file, copied from the Firebase console's app
  /// settings. Passed as options instead of google-services.json /
  /// GoogleService-Info.plist so builds without them still compile. Push
  /// alerts need Supabase too: that's where subscriptions are stored.
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const hasFirebase =
      hasSupabase && firebaseProjectId != '' && firebaseSenderId != '';
}
