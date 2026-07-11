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
    // No automatic sign-in: the owner signs in with an email magic link (see
    // AuthService / OwnerHome), which keeps the vault private. Recipients open a
    // share link and never sign in — the get_gallery/get_share functions serve
    // them through the public anon key.
  } catch (e) {
    bootError = e.toString();
  }

  runApp(PeekabooApp(bootError: bootError));
}
