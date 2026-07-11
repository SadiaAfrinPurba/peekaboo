import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner authentication via email magic link (passwordless).
///
/// The vault is private: only a signed-in owner reaches it. There are two ways
/// in:
///  - **Claim** — the very first time, on the browser that already holds the
///    anonymous session that owns the photos, we attach an email to that same
///    user with [claimWithEmail]. The user id (and therefore every photo,
///    gallery and storage object) is preserved.
///  - **Sign in** — afterwards, on any device, [sendMagicLink] emails a one-tap
///    link that logs into that same account.
class AuthService {
  static SupabaseClient get _c => Supabase.instance.client;

  static Session? get session => _c.auth.currentSession;
  static User? get user => _c.auth.currentUser;

  static bool get isSignedIn => session != null;

  /// A "claimed" (permanent) account has an email attached. Anonymous sessions
  /// don't, so we treat email presence as the private/permanent signal.
  static bool get isClaimed => (user?.email?.isNotEmpty ?? false);

  /// Signed in but not yet claimed — an anonymous session that still owns the
  /// photos and should attach an email to keep them.
  static bool get isAnonymous => isSignedIn && !isClaimed;

  static Stream<AuthState> get changes => _c.auth.onAuthStateChange;

  /// Emails a magic link to sign into an EXISTING owner account. Never creates
  /// a new user, so a stranger's email can't spin up a vault.
  static Future<void> sendMagicLink(String email) => _c.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
        emailRedirectTo: _redirect,
      );

  /// Attaches an email to the current anonymous user (keeps the same id), then
  /// emails a confirmation link. After confirming, the vault is private and the
  /// owner can sign in from anywhere with [sendMagicLink].
  static Future<void> claimWithEmail(String email) => _c.auth.updateUser(
        UserAttributes(email: email.trim()),
        emailRedirectTo: _redirect,
      );

  static Future<void> signOut() => _c.auth.signOut();

  /// Where the magic link should return to — the app's own base URL (origin +
  /// `/peekaboo/`), with any route fragment stripped.
  static String? get _redirect {
    if (!kIsWeb) return null;
    final full = Uri.base.toString();
    final hash = full.indexOf('#');
    return hash >= 0 ? full.substring(0, hash) : full;
  }
}
