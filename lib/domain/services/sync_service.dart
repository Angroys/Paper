import '../models/sync.dart';

/// Background outbox sync: push oldest first, then pull since the last
/// cursor; last-write-wins per row (losers kept as [ReplacedVersion]).
abstract interface class SyncService {
  SyncStatus get status;

  /// Emits the current status on listen, then every change.
  Stream<SyncStatus> watchStatus();

  /// Starts listening to connectivity/auth and syncs on reconnect.
  Future<void> start();

  Future<void> stop();

  /// Manual "Sync now" / Mod+Shift+S. No-op offline.
  Future<void> syncNow();

  Stream<List<SyncOp>> watchPendingOps();

  Future<void> retryOp(String opId);

  /// Drops a failed op (and reverts the local row where applicable).
  Future<void> discardOp(String opId);

  Stream<List<ReplacedVersion>> watchReplacedVersions();

  /// Writes the replaced local value again as a new (latest) write.
  Future<void> restoreReplaced(String replacedVersionId);

  Future<void> dismissReplaced(String replacedVersionId);
}
