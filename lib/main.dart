import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/api_constants.dart';
import 'core/error/errors.dart';
import 'core/storage/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Restores the stored anonymous session. Sign-in and sync happen later,
  // in the background (CitiesRepositoryImpl), never blocking the UI.
  if (ApiConstants.hasSupabase) {
    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      publishableKey: ApiConstants.supabaseAnonKey,
    );
  }
  if (ApiConstants.hasFirebase) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: ios
            ? ApiConstants.firebaseIosApiKey
            : ApiConstants.firebaseAndroidApiKey,
        appId: ios
            ? ApiConstants.firebaseIosAppId
            : ApiConstants.firebaseAndroidAppId,
        messagingSenderId: ApiConstants.firebaseSenderId,
        projectId: ApiConstants.firebaseProjectId,
      ),
    );
    // iOS hides pushes that arrive while the app is open unless told not to.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true, sound: true);
  }
  runApp(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}
