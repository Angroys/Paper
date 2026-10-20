import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/build_flags.dart';
import '../core/core_providers.dart';
import '../core/paper_api_client.dart';
import '../data/data_providers.dart';
import '../domain/domain.dart';
import '../sync/sync_providers.dart';
import 'local_auth_repository.dart';
import 'supabase_auth_repository.dart';
import 'unconfigured_auth_repository.dart';
import 'windows_protocol_registration.dart';

/// Auth: [SupabaseAuthRepository] once Supabase is initialised, else
/// [UnconfiguredAuthRepository]. On Windows the `paper://` handler is
/// (re-)registered under HKCU the first time this is read.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Offline-only builds: a local user, no sign-in screen.
  if (ref.watch(offlineOnlyProvider)) return const LocalAuthRepository();
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const UnconfiguredAuthRepository();
  unawaited(registerWindowsProtocolHandler());
  final repo = SupabaseAuthRepository(client.auth);
  ref.onDispose(() => unawaited(repo.dispose()));
  return repo;
});

/// Current auth state for widgets and the router.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).watchAuthState(),
);

/// OAuth / magic-link callback failures, for `AuthErrorBanner`.
final authErrorsProvider = StreamProvider<AuthFailedException>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo is SupabaseAuthRepository
      ? repo.authErrors
      : const Stream<AuthFailedException>.empty();
});

/// Fresh session JSON for the `@supabase/ssr` cookie (null signed out).
final freshSessionJsonProvider = Provider<FreshSessionJson>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo is SupabaseAuthRepository) return repo.freshSessionJson;
  return () async => null;
});

/// Signs out and wipes this device's data (DB, outbox, cached PDFs).
/// Show `SignOutDialog` first: local-only notes are lost
/// (`NoteRepository.countLocalOnlyNotes`).
final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final offline = ref.read(offlineOnlyProvider);
    if (!offline) await ref.read(syncEngineProvider).stop();
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(appDatabaseProvider).clearAll();
    await ref.read(fileStoreProvider).clear();
    if (!offline) ref.invalidate(syncEngineProvider);
  };
});
