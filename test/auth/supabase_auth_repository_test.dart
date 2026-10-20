import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:paper/auth/supabase_auth_repository.dart';
import 'package:paper/auth/windows_protocol_registration.dart';
import 'package:paper/core/app_links_deep_link_service.dart';
import 'package:paper/core/env.dart';
import 'package:paper/domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class MockGoTrue extends Mock implements sb.GoTrueClient {}

/// Unsigned JWT whose `exp` is [expiresIn] seconds from now.
String jwt(int expiresIn) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn;
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${b64({'sub': 'user-1', 'exp': exp})}.c2ln';
}

sb.Session session({int expiresIn = 3600, bool anonymous = false}) =>
    sb.Session(
      accessToken: jwt(expiresIn),
      refreshToken: 'refresh',
      expiresIn: expiresIn,
      tokenType: 'bearer',
      user: sb.User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {'full_name': 'Ada'},
        aud: 'authenticated',
        email: 'ada@example.com',
        createdAt: '2026-01-01T00:00:00Z',
        isAnonymous: anonymous,
      ),
    );

void main() {
  late MockGoTrue gotrue;
  late StreamController<sb.AuthState> events;
  late List<Uri> launched;
  sb.Session? current;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(sb.OAuthProvider.google);
  });

  setUp(() {
    gotrue = MockGoTrue();
    events = StreamController<sb.AuthState>.broadcast();
    launched = [];
    current = null;
    when(() => gotrue.currentSession).thenAnswer((_) => current);
    when(() => gotrue.onAuthStateChange).thenAnswer((_) => events.stream);
  });
  tearDown(() => events.close());

  SupabaseAuthRepository repo() => SupabaseAuthRepository(
    gotrue,
    launchExternal: (uri) async {
      launched.add(uri);
      return true;
    },
  );

  group('deep-link parsing', () {
    test('auth callback and open-paper links', () {
      expect(
        DeepLinkTarget.parse(Uri.parse('paper://auth-callback?code=abc')),
        isA<AuthCallbackLink>(),
      );
      final open = DeepLinkTarget.parse(Uri.parse('paper://paper/123'));
      expect(open, isA<OpenPaperLink>());
      expect((open! as OpenPaperLink).paperId, '123');
      expect(DeepLinkTarget.parse(Uri.parse('https://paper.college')), isNull);
      expect(
        SupabaseAuthRepository.isAuthCallback(
          Uri.parse('paper://auth-callback#access_token=x'),
        ),
        isTrue,
      );
    });

    test('Windows cold start passes the link in argv', () {
      expect(
        AppLinksDeepLinkService.linkFromArgs([
          '--flag',
          'paper://auth-callback?code=xyz',
        ]),
        Uri.parse('paper://auth-callback?code=xyz'),
      );
    });
  });

  test('Google opens the system browser with the PKCE URL', () async {
    when(
      () => gotrue.getOAuthSignInUrl(
        provider: sb.OAuthProvider.google,
        redirectTo: Env.authCallbackUrl,
      ),
    ).thenAnswer(
      (_) async => const sb.OAuthResponse(
        provider: sb.OAuthProvider.google,
        url: 'https://ref.supabase.co/auth/v1/authorize?provider=google',
      ),
    );
    await repo().signInWithGoogle();
    expect(launched.single.host, 'ref.supabase.co');
  });

  test('handleAuthCallback exchanges the code and signs in', () async {
    final uri = Uri.parse('paper://auth-callback?code=abc');
    when(() => gotrue.getSessionFromUrl(uri)).thenAnswer((_) async {
      current = session();
      return sb.AuthSessionUrlResponse(session: current!, redirectType: null);
    });
    final r = repo();
    expect(r.currentState, const AuthState.signedOut());
    final states = <AuthState>[];
    final sub = r.watchAuthState().listen(states.add);
    expect(await r.handleAuthCallback(uri), isTrue);
    await pumpEventQueue();
    expect(r.currentState.user?.id, 'user-1');
    expect(r.currentState.user?.displayName, 'Ada');
    expect(states.last.isSignedIn, isTrue);
    await sub.cancel();
  });

  test('non-auth links are not handled', () async {
    expect(
      await repo().handleAuthCallback(Uri.parse('paper://paper/1')),
      isFalse,
    );
    verifyNever(() => gotrue.getSessionFromUrl(any()));
  });

  test('denied consent reports cancelled', () async {
    final uri = Uri.parse(
      'paper://auth-callback?error=access_denied&error_description=denied',
    );
    when(() => gotrue.getSessionFromUrl(uri))
        .thenThrow(const sb.AuthException('denied', code: 'access_denied'));
    final r = repo();
    final errors = <AuthFailedException>[];
    final sub = r.authErrors.listen(errors.add);
    expect(await r.handleAuthCallback(uri), isTrue);
    await pumpEventQueue();
    expect(errors.single.reason, AuthFailureReason.cancelled);
    expect(r.currentState.isSignedIn, isFalse);
    await sub.cancel();
  });

  test('stale code reports exchangeFailed', () async {
    final uri = Uri.parse('paper://auth-callback?code=stale');
    when(
      () => gotrue.getSessionFromUrl(uri),
    ).thenThrow(const sb.AuthException('expired', code: 'flow_state_expired'));
    final r = repo();
    final errors = <AuthFailedException>[];
    final sub = r.authErrors.listen(errors.add);
    await r.handleAuthCallback(uri);
    await pumpEventQueue();
    expect(errors.single.reason, AuthFailureReason.exchangeFailed);
    await sub.cancel();
  });

  test('code already consumed by supabase_flutter still signs in', () async {
    final uri = Uri.parse('paper://auth-callback?code=abc');
    when(() => gotrue.getSessionFromUrl(uri)).thenAnswer((_) async {
      current = session(); // the other observer won the race
      throw const sb.AuthException('verifier missing');
    });
    final r = repo();
    final errors = <AuthFailedException>[];
    final sub = r.authErrors.listen(errors.add);
    await r.handleAuthCallback(uri);
    await pumpEventQueue();
    expect(errors, isEmpty);
    expect(r.currentState.isSignedIn, isTrue);
    await sub.cancel();
  });

  test('anonymous (web guest) sessions count as signed out', () {
    current = session(anonymous: true);
    expect(repo().currentState, const AuthState.signedOut());
  });

  test('email errors map to typed failures', () async {
    when(() => gotrue.signInWithPassword(email: 'a@b.c', password: 'x'))
        .thenThrow(
          const sb.AuthApiException(
            'Invalid login credentials',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        );
    await expectLater(
      repo().signInWithEmailPassword(email: ' a@b.c ', password: 'x'),
      throwsA(
        isA<AuthFailedException>().having(
          (e) => e.reason,
          'reason',
          AuthFailureReason.invalidCredentials,
        ),
      ),
    );
    expect(
      mapAuthException(sb.AuthRetryableFetchException()),
      isA<OfflineException>(),
    );
    expect(
      (mapAuthException(
        const sb.AuthException('slow', statusCode: '429'),
      ) as AuthFailedException).reason,
      AuthFailureReason.rateLimited,
    );
    expect(
      (mapAuthException(
        const sb.AuthException('x', code: 'email_not_confirmed'),
      ) as AuthFailedException).reason,
      AuthFailureReason.emailNotConfirmed,
    );
  });

  test('sign-up reports when email confirmation is needed', () async {
    when(
      () => gotrue.signUp(
        email: 'a@b.c',
        password: 'pw',
        emailRedirectTo: Env.authCallbackUrl,
      ),
    ).thenAnswer((_) async => sb.AuthResponse());
    expect(
      await repo().signUpWithEmailPassword(email: 'a@b.c', password: 'pw'),
      isTrue,
    );
  });

  test('accessToken refreshes a session that is about to expire', () async {
    current = session(expiresIn: 60);
    when(() => gotrue.refreshSession()).thenAnswer((_) async {
      current = session();
      return sb.AuthResponse(session: current);
    });
    expect(await repo().accessToken(), isNotNull);
    verify(() => gotrue.refreshSession()).called(1);

    current = session();
    clearInteractions(gotrue);
    await repo().freshSessionJson();
    verifyNever(() => gotrue.refreshSession());
  });

  test('refused refresh -> AuthExpiredException', () async {
    current = session(expiresIn: 10);
    when(() => gotrue.refreshSession())
        .thenThrow(const sb.AuthApiException('revoked', statusCode: '400'));
    await expectLater(
      repo().accessToken(),
      throwsA(isA<AuthExpiredException>()),
    );
  });

  test('Windows protocol registration writes HKCU keys', () async {
    final calls = <List<String>>[];
    final ok = await registerWindowsProtocolHandler(
      isWindows: true,
      executablePath: r'C:\Paper\paper.exe',
      run: (exe, args) async {
        calls.add([exe, ...args]);
        return ProcessResult(0, 0, '', '');
      },
    );
    expect(ok, isTrue);
    expect(calls, hasLength(3));
    expect(calls.first, contains(r'HKCU\Software\Classes\paper'));
    expect(calls.last, contains(r'"C:\Paper\paper.exe" "%1"'));
    expect(await registerWindowsProtocolHandler(isWindows: false), isFalse);
  });
}
