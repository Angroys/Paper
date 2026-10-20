import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../core/core_providers.dart';
import '../data/data_providers.dart';
import '../domain/domain.dart';
import 'sync_engine.dart';

/// Fires on app resume (sync trigger).
final appResumeSignalsProvider = Provider<Stream<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  final listener = AppLifecycleListener(onResume: () => controller.add(null));
  ref.onDispose(() {
    listener.dispose();
    unawaited(controller.close());
  });
  return controller.stream;
});

/// The outbox sync engine (see lib/sync/sync_engine.dart for the rules).
/// `SyncLifecycle` (lib/app/app.dart) starts it after sign-in and stops it
/// on sign-out.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final engine = SyncEngine(
    store: ref.watch(localStoreProvider),
    remote: ref.watch(remoteDataSourceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    authStates: auth.watchAuthState(),
    currentAuth: () => auth.currentState,
    resumeSignals: ref.watch(appResumeSignalsProvider),
  );
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

/// Outbox sync, as the domain interface.
final syncServiceProvider = Provider<SyncService>(
  (ref) => ref.watch(syncEngineProvider),
);

/// SyncBadge / SyncSheet state.
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncServiceProvider).watchStatus(),
);

/// SyncSheet lists.
final pendingOpsProvider = StreamProvider<List<SyncOp>>(
  (ref) => ref.watch(syncServiceProvider).watchPendingOps(),
);

final replacedVersionsProvider = StreamProvider<List<ReplacedVersion>>(
  (ref) => ref.watch(syncServiceProvider).watchReplacedVersions(),
);
