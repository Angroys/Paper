import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:url_launcher/url_launcher.dart';

import '../core/env.dart';
import '../core/streams.dart';
import '../domain/domain.dart';

/// Opens [url] outside the app (system browser). Injectable for tests.
typedef ExternalUrlLauncher = Future<bool> Function(Uri url);

Future<bool> _launchExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// [AuthRepository] on supabase_flutter / GoTrue.
///
/// * Google: PKCE OAuth in the **system browser**
///   (`LaunchMode.externalApplication`, never a webview) with
///   `redirectTo: paper://auth-callback`. This is what
///   `supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: ...,
///   authScreenLaunchMode: LaunchMode.externalApplication)` does; it is
///   spelled out with `getOAuthSignInUrl` so tests can mock GoTrue (the
///   supabase_flutter helper is an extension method).
/// * The browser returns to `paper://auth-callback?code=...`;
///   [handleAuthCallback] exchanges the code (`getSessionFromUrl`). Cold
///   start: `DeepLinkListener` passes the initial link (Android intent,
///   macOS open-URL, Windows argv) to the same method.
/// * Email: password sign-in / sign-up, magic link and password reset, all
///   redirecting to `paper://auth-callback`. A password-recovery link signs
///   the user in on this device (PKCE: only the device that asked can
///   exchange it); there is no "set new password" screen in v1.
/// * Guests: RPR's web app signs visitors in with anonymous Supabase
///   identities. The native app requires a real account, so it never calls
///   `signInAnonymously`, and an anonymous session found on disk is treated
///   as signed out.
///
/// Callback failures (cancelled, denied, stale code) are not thrown, since
/// the deep-link listener fires and forgets them. They go to [authErrors]
/// so the sign-in screen can show `AuthErrorBanner`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._auth, {
    ExternalUrlLauncher launchExternal = _launchExternal,
    this._redirectUrl = Env.authCallbackUrl,
    DateTime Function()? clock,
    this.refreshMargin = const Duration(minutes: 5),
  }) : _launch = launchExternal,
       _now = clock ?? DateTime.now {
    // The client only exists after Supabase.initialize, which already
    // restored the persisted session, so the state is known right away.
    _state = _fromSession(_auth.currentSession);
    _sub = _auth.onAuthStateChange.listen(
      (event) => _emit(_fromSession(event.session)),
      // GoTrue reports failed URL exchanges here too; handled per call.
      onError: (Object _) {},
    );
  }

  final sb.GoTrueClient _auth;
  final ExternalUrlLauncher _launch;
  final String _redirectUrl;
  final DateTime Function() _now;

  /// Refresh the access token when it expires sooner than this.
  final Duration refreshMargin;

  late AuthState _state;
  StreamSubscription<sb.AuthState>? _sub;
  final _states = StreamController<AuthState>.broadcast();
  final _errors = StreamController<AuthFailedException>.broadcast();

  /// Failures of [handleAuthCallback] (OAuth / magic-link returns).
  Stream<AuthFailedException> get authErrors => _errors.stream;

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> watchAuthState() =>
      currentThenChanges(() => _state, _states.stream);

  @override
  Future<AuthState> restoreSession() async {
    // supabase_flutter restores the persisted session during
    // Supabase.initialize (local storage, no network); just read it.
    _emit(_fromSession(_auth.currentSession));
    return _state;
  }

  @override
  Future<void> signInWithGoogle() async {
    final sb.OAuthResponse res;
    try {
      res = await _auth.getOAuthSignInUrl(
        provider: sb.OAuthProvider.google,
        redirectTo: _redirectUrl,
      );
    } on sb.AuthException catch (e) {
      throw mapAuthException(e);
    }
    final launched = await _launch(Uri.parse(res.url));
    if (!launched) {
      throw const AuthFailedException(
        AuthFailureReason.unknown,
        'Could not open the system browser',
      );
    }
  }

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithPassword(email: email.trim(), password: password),
  );

  @override
  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final res = await _guard(
      () => _auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _redirectUrl,
      ),
    );
    return res.session == null;
  }

  @override
  Future<void> sendMagicLink(String email) => _guard(
    () =>
        _auth.signInWithOtp(email: email.trim(), emailRedirectTo: _redirectUrl),
  );

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(email.trim(), redirectTo: _redirectUrl),
  );

  /// True for `paper://auth-callback...`.
  static bool isAuthCallback(Uri uri) =>
      DeepLinkTarget.parse(uri) is AuthCallbackLink;

  @override
  Future<bool> handleAuthCallback(Uri uri) async {
    if (!isAuthCallback(uri)) return false;
    final hadSession = _isRealSession(_auth.currentSession);
    if (hadSession && !_hasCode(uri)) return true;
    try {
      await _auth.getSessionFromUrl(uri);
      _emit(_fromSession(_auth.currentSession));
    } on sb.AuthException catch (e) {
      // supabase_flutter's own deep-link observer (detectSessionInUri) may
      // have consumed the same code first; then we are signed in already.
      if (!hadSession && _isRealSession(_auth.currentSession)) {
        _emit(_fromSession(_auth.currentSession));
        return true;
      }
      _errors.add(_callbackFailure(e, uri));
    } on Object catch (e) {
      _errors.add(
        AuthFailedException(AuthFailureReason.exchangeFailed, e.toString()),
      );
    }
    return true;
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on sb.AuthException {
      // Offline: the local session is removed anyway.
    }
    _emit(const AuthState.signedOut());
  }

  @override
  Future<String?> accessToken() async => (await freshSession())?.accessToken;

  /// The current session, refreshed first if it expires within
  /// [refreshMargin]; null when signed out. Throws `OfflineException` /
  /// `AuthExpiredException` when a needed refresh fails.
  Future<sb.Session?> freshSession() async {
    final session = _auth.currentSession;
    if (!_isRealSession(session)) return null;
    final expiresAt = session!.expiresAt;
    if (expiresAt != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        expiresAt * 1000,
        isUtc: true,
      );
      if (expiry.difference(_now().toUtc()) < refreshMargin) {
        try {
          final res = await _auth.refreshSession();
          return res.session ?? _auth.currentSession;
        } on sb.AuthRetryableFetchException catch (e) {
          throw OfflineException(e.message);
        } on sb.AuthException catch (e) {
          throw AuthExpiredException(e.message);
        }
      }
    }
    return session;
  }

  /// [freshSession] as supabase-js JSON, for the `@supabase/ssr` cookie.
  Future<Map<String, Object?>?> freshSessionJson() async =>
      (await freshSession())?.toJson().cast<String, Object?>();

  Future<void> dispose() async {
    await _sub?.cancel();
    await _states.close();
    await _errors.close();
  }

  void _emit(AuthState state) {
    if (state == _state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  static bool _hasCode(Uri uri) =>
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('access_token');

  static bool _isRealSession(sb.Session? s) => s != null && !s.user.isAnonymous;

  AuthState _fromSession(sb.Session? session) {
    if (!_isRealSession(session)) return const AuthState.signedOut();
    final user = session!.user;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    return AuthState.signedIn(
      AppUser(
        id: user.id,
        email: user.email,
        displayName: (meta['full_name'] ?? meta['name']) as String?,
        avatarUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
        isAnonymous: user.isAnonymous,
      ),
    );
  }

  AuthFailedException _callbackFailure(sb.AuthException e, Uri uri) {
    final error = uri.queryParameters['error'] ?? e.code;
    if (error == 'access_denied') {
      return AuthFailedException(AuthFailureReason.cancelled, e.message);
    }
    return AuthFailedException(AuthFailureReason.exchangeFailed, e.message);
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on sb.AuthException catch (e) {
      throw mapAuthException(e);
    }
  }
}

/// Maps a GoTrue error to the domain's typed failures.
PaperException mapAuthException(sb.AuthException e) {
  if (e is sb.AuthRetryableFetchException) {
    return OfflineException(e.message);
  }
  final code = e.code;
  final status = e.statusCode;
  if (code == 'invalid_credentials' ||
      (status == '400' && e.message.contains('Invalid login credentials'))) {
    return AuthFailedException(AuthFailureReason.invalidCredentials, e.message);
  }
  if (code == 'email_not_confirmed') {
    return AuthFailedException(AuthFailureReason.emailNotConfirmed, e.message);
  }
  if (status == '429' ||
      code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit') {
    return AuthFailedException(AuthFailureReason.rateLimited, e.message);
  }
  if (code == 'flow_state_not_found' ||
      code == 'flow_state_expired' ||
      code == 'bad_code_verifier' ||
      e is sb.AuthPKCEGrantCodeExchangeError) {
    return AuthFailedException(AuthFailureReason.exchangeFailed, e.message);
  }
  return AuthFailedException(AuthFailureReason.unknown, e.message);
}
