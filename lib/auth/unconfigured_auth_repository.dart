import '../domain/domain.dart';

/// [AuthRepository] for builds without Supabase config (tests, bare
/// `flutter run`). Always [AuthStatus.notConfigured]; every sign-in throws
/// [NotConfiguredException].
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  static const AuthState _state = AuthState.notConfigured();

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> watchAuthState() => Stream<AuthState>.value(_state);

  @override
  Future<AuthState> restoreSession() async => _state;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<bool> handleAuthCallback(Uri uri) async => false;

  Never _fail() => throw const NotConfiguredException(
    'Supabase is not configured; pass --dart-define-from-file=env/<name>.json',
  );

  @override
  Future<void> signInWithGoogle() async => _fail();

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => _fail();

  @override
  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async => _fail();

  @override
  Future<void> sendMagicLink(String email) async => _fail();

  @override
  Future<void> sendPasswordReset(String email) async => _fail();

  @override
  Future<void> signOut() async {}
}
