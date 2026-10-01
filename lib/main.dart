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
import 'features/alerts/data/alerts_sync_ds.dart';

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
  final pushReady = ApiConstants.hasFirebase && await _initFirebase();
  runApp(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (!pushReady) alertsSyncDataSourceProvider.overrideWithValue(null),
      ],
      child: const App(),
    ),
  );
}

/// False when this platform's keys are missing or wrong: push alerts are
/// then hidden, rather than the whole app failing to start.
Future<bool> _initFirebase() async {
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  try {
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
    return true;
  } catch (e) {
    debugPrint('Push alerts off, Firebase failed to start: $e');
    return false;
  }
}
