import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/build_flags.dart';
import '../core/core_providers.dart';
import '../core/paper_api_client.dart';
import '../data/data_providers.dart';
import '../domain/domain.dart';
import '../sync/guest_merge.dart';
import '../sync/sync_providers.dart';
import 'local_auth_repository.dart';
import 'supabase_auth_repository.dart';
import 'unconfigured_auth_repository.dart';

/// Auth: [SupabaseAuthRepository] once Supabase is initialised, else
/// [UnconfiguredAuthRepository]. (On Windows `main()` registers the
/// `paper://` handler under HKCU at startup.)
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Offline-only builds: a local user, no sign-in screen.
  if (ref.watch(offlineOnlyProvider)) return const LocalAuthRepository();
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const UnconfiguredAuthRepository();
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

/// Online build with Supabase configured and nobody signed in: the app
/// runs as a guest (sign-in is optional). Online-only features (sync, AI,
/// import by link) then show a "Sign in to use …" prompt instead of
/// running. Always false in offline-only and unconfigured builds.
final isGuestProvider = Provider<bool>((ref) {
  if (ref.watch(offlineOnlyProvider)) return false;
  final auth =
      ref.watch(authStateProvider).value ??
      ref.watch(authRepositoryProvider).currentState;
  return auth.status == AuthStatus.signedOut;
});

/// Signs out; the app carries on as a guest. Show `SignOutDialog` first.
///
/// * [keepLocalData] true (the default): papers on this device stay
///   readable, labelled as kept from the account (`PaperKeptChip`); papers
///   that are only in the cloud are removed. The account's queued changes
///   stay and sync if the same account signs in again; another account
///   signing in removes them (lib/sync/guest_merge.dart).
/// * false: wipes this device's data (DB, outbox, cached PDFs). Local-only
///   notes are lost (`NoteRepository.countLocalOnlyNotes`).
final signOutProvider = Provider<Future<void> Function({bool keepLocalData})>((
  ref,
) {
  return ({bool keepLocalData = true}) async {
    final offline = ref.read(offlineOnlyProvider);
    if (!offline) await ref.read(syncEngineProvider).stop();
    await ref.read(authRepositoryProvider).signOut();
    if (keepLocalData) {
      await GuestDataMerge(ref.read(localStoreProvider))
          .keepDeviceCopiesForGuest();
    } else {
      await ref.read(appDatabaseProvider).clearAll();
      await ref.read(fileStoreProvider).clear();
    }
    if (!offline) ref.invalidate(syncEngineProvider);
  };
});
