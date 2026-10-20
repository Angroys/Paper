import 'package:meta/meta.dart';

import 'json.dart';

/// Entities the outbox can carry. Only what the RPR schema accepts
/// (option A): notes, colours and reading position never enter the outbox.
enum SyncEntity { paper, highlight, figureHighlight }

enum SyncOpKind { create, update, delete }

/// One outbox row: a local write waiting to be pushed to Supabase.
/// Pushed oldest first; conflicts resolve last-write-wins per row.
@immutable
class SyncOp {
  const SyncOp({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.kind,
    required this.createdAt,
    required this.localUpdatedAt,
    required this.deviceId,
    this.payload = const <String, Object?>{},
    this.attempts = 0,
    this.lastError,
  });

  factory SyncOp.fromJson(Map<String, Object?> json) => SyncOp(
    id: json['id']! as String,
    entity: SyncEntity.values.byName(json['entity']! as String),
    entityId: json['entity_id']! as String,
    kind: SyncOpKind.values.byName(json['kind']! as String),
    payload: json['payload'] == null
        ? const <String, Object?>{}
        : asJsonMap(json['payload']),
    createdAt: parseDate(json['created_at']),
    localUpdatedAt: parseDate(json['local_updated_at']),
    deviceId: json['device_id']! as String,
    attempts: toIntOrNull(json['attempts']) ?? 0,
    lastError: json['last_error'] as String?,
  );

  final String id;
  final SyncEntity entity;
  final String entityId;
  final SyncOpKind kind;

  /// Server columns to write (snake_case), e.g. `Paper.toSupabaseRow()`.
  final Map<String, Object?> payload;
  final DateTime createdAt;

  /// Local clock at the time of the edit (LWW input).
  final DateTime localUpdatedAt;
  final String deviceId;
  final int attempts;
  final String? lastError;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'entity': entity.name,
    'entity_id': entityId,
    'kind': kind.name,
    'payload': payload,
    'created_at': dateToJson(createdAt),
    'local_updated_at': dateToJson(localUpdatedAt),
    'device_id': deviceId,
    'attempts': attempts,
    'last_error': lastError,
  };

  SyncOp copyWith({int? attempts, Object? lastError = unset}) => SyncOp(
    id: id,
    entity: entity,
    entityId: entityId,
    kind: kind,
    payload: payload,
    createdAt: createdAt,
    localUpdatedAt: localUpdatedAt,
    deviceId: deviceId,
    attempts: attempts ?? this.attempts,
    lastError: identical(lastError, unset)
        ? this.lastError
        : lastError as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is SyncOp &&
      other.id == id &&
      other.entity == entity &&
      other.entityId == entityId &&
      other.kind == kind &&
      _mapEquals(other.payload, payload) &&
      other.createdAt == createdAt &&
      other.localUpdatedAt == localUpdatedAt &&
      other.deviceId == deviceId &&
      other.attempts == attempts &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    entityId,
    kind,
    createdAt,
    localUpdatedAt,
    deviceId,
    attempts,
    lastError,
  );
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    final av = a[key];
    final bv = b[key];
    if (av is Map<String, Object?> && bv is Map<String, Object?>) {
      if (!_mapEquals(av, bv)) return false;
    } else if (av is List<Object?> && bv is List<Object?>) {
      if (!listEquals(av, bv)) return false;
    } else if (av != bv) {
      return false;
    }
  }
  return true;
}

/// The five SyncBadge states (design/specs/screens/sync-status.md).
enum SyncPhase { synced, syncing, pending, offline, error }

/// Snapshot for SyncBadge / SyncSheet.
@immutable
class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.progressDone = 0,
    this.progressTotal = 0,
    this.lastSyncedAt,
    this.authExpired = false,
  });

  /// Nothing has synced yet and nothing is pending.
  static const SyncStatus idle = SyncStatus(phase: SyncPhase.synced);

  final SyncPhase phase;

  /// Outbox rows not yet pushed (device-only data never counts).
  final int pendingCount;
  final int failedCount;
  final int progressDone;
  final int progressTotal;
  final DateTime? lastSyncedAt;

  /// Error is "session expired, sign in again" (data stays in the outbox).
  final bool authExpired;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.phase == phase &&
      other.pendingCount == pendingCount &&
      other.failedCount == failedCount &&
      other.progressDone == progressDone &&
      other.progressTotal == progressTotal &&
      other.lastSyncedAt == lastSyncedAt &&
      other.authExpired == authExpired;

  @override
  int get hashCode => Object.hash(
    phase,
    pendingCount,
    failedCount,
    progressDone,
    progressTotal,
    lastSyncedAt,
    authExpired,
  );
}

/// A local value that lost a last-write-wins conflict. Kept 30 days so the
/// user can "Restore mine" from SyncSheet › Replaced versions.
@immutable
class ReplacedVersion {
  const ReplacedVersion({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.mine,
    required this.mineUpdatedAt,
    required this.theirsUpdatedAt,
    required this.replacedAt,
  });

  factory ReplacedVersion.fromJson(Map<String, Object?> json) =>
      ReplacedVersion(
        id: json['id']! as String,
        entity: SyncEntity.values.byName(json['entity']! as String),
        entityId: json['entity_id']! as String,
        mine: asJsonMap(json['mine']),
        mineUpdatedAt: parseDate(json['mine_updated_at']),
        theirsUpdatedAt: parseDate(json['theirs_updated_at']),
        replacedAt: parseDate(json['replaced_at']),
      );

  final String id;
  final SyncEntity entity;
  final String entityId;

  /// The overwritten local row (toJson form).
  final Map<String, Object?> mine;
  final DateTime mineUpdatedAt;
  final DateTime theirsUpdatedAt;
  final DateTime replacedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'entity': entity.name,
    'entity_id': entityId,
    'mine': mine,
    'mine_updated_at': dateToJson(mineUpdatedAt),
    'theirs_updated_at': dateToJson(theirsUpdatedAt),
    'replaced_at': dateToJson(replacedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is ReplacedVersion &&
      other.id == id &&
      other.entity == entity &&
      other.entityId == entityId &&
      _mapEquals(other.mine, mine) &&
      other.mineUpdatedAt == mineUpdatedAt &&
      other.theirsUpdatedAt == theirsUpdatedAt &&
      other.replacedAt == replacedAt;

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    entityId,
    mineUpdatedAt,
    theirsUpdatedAt,
    replacedAt,
  );
}
