import '../models/auth.dart';

/// Supabase auth (Google OAuth via system browser + `paper://auth-callback`,
/// email/password, magic link). Failures throw `AuthFailedException`,
/// `OfflineException` or `NotConfiguredException` (lib/domain/errors.dart).
abstract interface class AuthRepository {
  /// Latest known state; [AuthStatus.unknown] until [restoreSession] ends.
  AuthState get currentState;

  /// Emits the current state on listen, then every change.
  Stream<AuthState> watchAuthState();

  /// Restores the persisted session from local storage. Must not wait on
  /// the network (the splash is held on this, capped at 2 s).
  Future<AuthState> restoreSession();

  /// Opens the system browser for Google OAuth (PKCE). Completes when the
  /// browser was launched; the session arrives via [handleAuthCallback].
  Future<void> signInWithGoogle();

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Returns true when the account needs email confirmation first.
  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
  });

  /// Sends a magic sign-in link that returns to `paper://auth-callback`.
  Future<void> sendMagicLink(String email);

  Future<void> sendPasswordReset(String email);

  /// Completes OAuth / magic-link sign-in from a `paper://auth-callback`
  /// URI (cold start or warm). Returns true if it was an auth URI.
  Future<bool> handleAuthCallback(Uri uri);

  /// Signs out and lets callers clear local data.
  Future<void> signOut();

  /// Current access token (JWT) for bearer calls to the paper.college API,
  /// refreshed if needed; null when signed out.
  Future<String?> accessToken();
}
