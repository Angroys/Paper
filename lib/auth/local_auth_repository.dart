import '../domain/domain.dart';

/// [AuthRepository] for offline-only builds (`PAPER_OFFLINE_ONLY`): always
/// signed in as [localUser], so the library opens without a sign-in screen.
/// Nothing here touches the network; every sign-in call throws
/// [NotConfiguredException] (no UI offers one in that build).
class LocalAuthRepository implements AuthRepository {
  const LocalAuthRepository();

  /// The device's only user ([kGuestUserId], a fixed nil UUID, so local
  /// rows keep a UUID-shaped `user_id`).
  static const AppUser localUser = AppUser(id: kGuestUserId);

  static const AuthState _state = AuthState.signedIn(localUser);

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> watchAuthState() => Stream<AuthState>.value(_state);

  @override
  Future<AuthState> restoreSession() async => _state;

  @override
  Future<String?> accessToken() async => null;

  /// `paper://auth-callback` is inert in this build.
  @override
  Future<bool> handleAuthCallback(Uri uri) async => false;

  Never _fail() =>
      throw const NotConfiguredException('Offline-only build: no sign-in');

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
