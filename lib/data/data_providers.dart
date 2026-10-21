import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../auth/auth_providers.dart';
import '../core/build_flags.dart';
import '../core/core_providers.dart';
import '../core/paper_api_client.dart';
import '../domain/domain.dart';
import '../sync/sync_providers.dart';
import 'db/app_database.dart';
import 'db/open_database.dart';
import 'file_store.dart';
import 'local_highlight_repository.dart';
import 'local_note_repository.dart';
import 'local_paper_repository.dart';
import 'local_store.dart';
import 'remote/remote_data_source.dart';
import 'remote/supabase_remote_data_source.dart';
import 'remote/unconfigured_remote_data_source.dart';

// Data layer wiring. Feature code depends only on the repository providers
// and the interfaces in lib/domain/. Tests override any layer:
//
//   ProviderScope(overrides: [
//     paperRepositoryProvider.overrideWithValue(FakePaperRepository()),
//     // or keep the real repositories on an in-memory DB + fake server:
//     appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
//     remoteDataSourceProvider.overrideWithValue(FakeRemote()),
//   ], child: ...)

/// Whether the DB and PDFs live on disk. Defaults to "configured";
/// `main()` also turns it on for offline-only builds. Unconfigured builds
/// (tests, bare `flutter run`) use throwaway storage.
final persistentStorageProvider = Provider<bool>(
  (ref) => ref.watch(envProvider).isConfigured,
);

/// The SQLite database: `paper.sqlite` in the app support dir when
/// [persistentStorageProvider], else a throwaway in-memory DB.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = ref.watch(persistentStorageProvider)
      ? openAppDatabase()
      : AppDatabase(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

/// Downloaded PDFs + figure crops on disk.
final fileStoreProvider = Provider<FileStore>((ref) {
  if (ref.watch(persistentStorageProvider)) {
    return FileStore(getApplicationSupportDirectory);
  }
  return FileStore(
    () async => Directory.systemTemp.createTemp('paper-unconfigured-'),
  );
});

/// Clock for local writes (override in tests).
final dataClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(
    db: ref.watch(appDatabaseProvider),
    files: ref.watch(fileStoreProvider),
    clock: ref.watch(dataClockProvider),
  ),
);

/// Shared HTTP client.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// paper.college API client (`@supabase/ssr` cookie auth); null when the
/// build is not configured.
final paperApiClientProvider = Provider<PaperApiClient?>((ref) {
  if (ref.watch(offlineOnlyProvider)) return null;
  final env = ref.watch(envProvider);
  if (!env.isConfigured) return null;
  return PaperApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUri: env.paperApiBaseUri,
    supabaseUrl: env.supabaseUrl,
    session: ref.watch(freshSessionJsonProvider),
  );
});

/// Supabase tables + storage (+ URL import through the API).
final remoteDataSourceProvider = Provider<RemoteDataSource>((ref) {
  if (ref.watch(offlineOnlyProvider)) {
    return const UnconfiguredRemoteDataSource();
  }
  final client = ref.watch(supabaseClientProvider);
  final api = ref.watch(paperApiClientProvider);
  if (client == null || api == null) {
    return const UnconfiguredRemoteDataSource();
  }
  return SupabaseRemoteDataSource(
    client: client,
    api: api,
    httpClient: ref.watch(httpClientProvider),
  );
});

/// Owner of new local rows: the signed-in account, else the guest
/// ([kGuestUserId]; sign-in is optional). Guest rows are re-owned on
/// sign-in (lib/sync/guest_merge.dart).
String _currentUserId(Ref ref) =>
    ref.read(authRepositoryProvider).currentState.user?.id ?? kGuestUserId;

final paperRepositoryProvider = Provider<PaperRepository>(
  (ref) => LocalPaperRepository(
    store: ref.watch(localStoreProvider),
    remote: ref.watch(remoteDataSourceProvider),
    currentUserId: () => _currentUserId(ref),
    // Offline-only builds never pull (no sync engine is built).
    pull: ref.watch(offlineOnlyProvider)
        ? null
        : () => ref.read(syncEngineProvider).pull(),
  ),
);

final highlightRepositoryProvider = Provider<HighlightRepository>(
  (ref) => LocalHighlightRepository(
    store: ref.watch(localStoreProvider),
    currentUserId: () => _currentUserId(ref),
  ),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => LocalNoteRepository(store: ref.watch(localStoreProvider)),
);
