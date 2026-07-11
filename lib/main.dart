import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/screen_protection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start listening for iOS screenshot events (no-op on web/Android).
  ScreenProtection.instance.init();

  String? bootError;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );

    // The owner is signed in silently & anonymously — no login screen, and the
    // session persists on this device. (Upgrade path: link an email so the
    // vault follows the user across devices.) Recipients viewing a link don't
    // need this, so a failure here is non-fatal.
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      try {
        await auth.signInAnonymously();
      } catch (_) {
        // Anonymous provider likely disabled — the gallery surfaces guidance.
      }
    }
  } catch (e) {
    bootError = e.toString();
  }

  runApp(PeekabooApp(bootError: bootError));
}
