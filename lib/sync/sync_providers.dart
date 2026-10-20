import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/domain.dart';

/// Outbox sync. Placeholder: the data-layer agent replaces the body.
final syncServiceProvider = Provider<SyncService>(
  (ref) => throw UnimplementedError('syncServiceProvider: data layer'),
);

/// SyncBadge / SyncSheet state.
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncServiceProvider).watchStatus(),
);
