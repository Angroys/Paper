/// Per-row sync state stored next to every locally mirrored row.
///
/// Option A (local-first, design/specs/flows.md "Data-model gap"): rows the
/// server schema cannot hold are [localOnly] and never count as pending.
enum SyncState {
  /// Matches the server.
  synced,

  /// Created locally; the create is in the outbox.
  pendingCreate,

  /// Changed locally; the update is in the outbox.
  pendingUpdate,

  /// Deleted locally (tombstone); the delete is in the outbox.
  pendingDelete,

  /// The server rejected the last op (see the outbox row's error).
  failed,

  /// Device-only data that is never synced (notes, colours, reading
  /// position in v1).
  localOnly;

  bool get isPending =>
      this == pendingCreate || this == pendingUpdate || this == pendingDelete;

  static SyncState fromName(String? name) => name == null
      ? SyncState.synced
      : SyncState.values.firstWhere(
          (s) => s.name == name,
          orElse: () => SyncState.synced,
        );
}
