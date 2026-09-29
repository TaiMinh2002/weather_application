import 'package:supabase_flutter/supabase_flutter.dart';

extension AnonymousSession on SupabaseClient {
  /// No login screen: each install signs in anonymously once and the session
  /// is kept on the device.
  Future<String> anonymousUserId() async {
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) throw const AuthException('Anonymous sign-in failed');
    return user.id;
  }
}
