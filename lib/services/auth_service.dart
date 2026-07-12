import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner / co-owner authentication via email + password (instant, no email
/// round-trip once "Confirm email" is off in the Supabase dashboard).
///
/// Two ways to get a private, permanent account:
///  - **Claim** — the founding owner, on the browser that already holds the
///    anonymous session that owns the photos, attaches an email + password to
///    that same user with [claim]. The user id (and every photo, gallery and
///    storage object) is preserved.
///  - **Sign up / Sign in** — a co-owner (e.g. a spouse) creates their own
///    account with [signUp] and joins the shared vault via an invite link.
class AuthService {
  static SupabaseClient get _c => Supabase.instance.client;

  static Session? get session => _c.auth.currentSession;
  static User? get user => _c.auth.currentUser;

  static bool get isSignedIn => session != null;

  /// A permanent account has an email attached; anonymous sessions don't.
  static bool get isClaimed => (user?.email?.isNotEmpty ?? false);
  static bool get isAnonymous => isSignedIn && !isClaimed;

  static Stream<AuthState> get changes => _c.auth.onAuthStateChange;

  static Future<void> signIn(String email, String password) =>
      _c.auth.signInWithPassword(email: email.trim(), password: password);

  static Future<void> signUp(String email, String password) =>
      _c.auth.signUp(email: email.trim(), password: password);

  /// Converts the current anonymous session into a permanent account, keeping
  /// the same user id (so existing photos stay put).
  static Future<void> claim(String email, String password) => _c.auth.updateUser(
        UserAttributes(email: email.trim(), password: password),
      );

  static Future<void> signOut() => _c.auth.signOut();
}
