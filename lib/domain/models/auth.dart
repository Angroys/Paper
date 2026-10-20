import 'package:meta/meta.dart';

/// The signed-in user (subset of Supabase `User` + `profiles`).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.isAnonymous = false,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.isAnonymous == isAnonymous;

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, avatarUrl, isAnonymous);
}

enum AuthStatus {
  /// Session restore has not finished (splash / skeleton).
  unknown,
  signedOut,
  signedIn,

  /// The build has no Supabase config; auth is impossible.
  notConfigured,
}

@immutable
class AuthState {
  const AuthState._(this.status, this.user);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.signedOut() : this._(AuthStatus.signedOut, null);
  const AuthState.signedIn(AppUser user) : this._(AuthStatus.signedIn, user);
  const AuthState.notConfigured() : this._(AuthStatus.notConfigured, null);

  final AuthStatus status;
  final AppUser? user;

  bool get isSignedIn => status == AuthStatus.signedIn;

  @override
  bool operator ==(Object other) =>
      other is AuthState && other.status == status && other.user == user;

  @override
  int get hashCode => Object.hash(status, user);
}
