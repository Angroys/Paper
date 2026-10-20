import '../domain/domain.dart';

/// [SyncService] for offline-only builds (`PAPER_OFFLINE_ONLY`): never
/// syncs, never talks to the network. Local writes still land in SQLite;
/// the outbox simply never drains.
class DisabledSyncService implements SyncService {
  const DisabledSyncService();

  @override
  SyncStatus get status => SyncStatus.idle;

  @override
  Stream<SyncStatus> watchStatus() => Stream<SyncStatus>.value(status);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> syncNow() async {}

  @override
  Stream<List<SyncOp>> watchPendingOps() =>
      Stream<List<SyncOp>>.value(const <SyncOp>[]);

  @override
  Future<void> retryOp(String opId) async {}

  @override
  Future<void> discardOp(String opId) async {}

  @override
  Stream<List<ReplacedVersion>> watchReplacedVersions() =>
      Stream<List<ReplacedVersion>>.value(const <ReplacedVersion>[]);

  @override
  Future<void> restoreReplaced(String replacedVersionId) async {}

  @override
  Future<void> dismissReplaced(String replacedVersionId) async {}
}
