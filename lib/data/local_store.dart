import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/domain.dart';
import '../domain/models/json.dart';
import 'db/app_database.dart';
import 'file_store.dart';
import 'mappers.dart';

/// Payload keys starting with `_` are bookkeeping for the sync engine and
/// are never sent to Supabase (e.g. [baseUpdatedAtKey]).
const String baseUpdatedAtKey = '_base_updated_at';

/// SQLite `rowid`: insertion order, the outbox tie-breaker for ops queued
/// in the same microsecond.
const Expression<int> insertionOrder = CustomExpression<int>('rowid');

/// Strips bookkeeping keys from an op payload.
Map<String, Object?> serverPayload(Map<String, Object?> payload) => {
  for (final e in payload.entries)
    if (!e.key.startsWith('_')) e.key: e.value,
};

/// Shared local-first plumbing for the repositories and the sync engine:
/// the drift DB, the outbox, the clock, ids and the file cache.
class LocalStore {
  LocalStore({
    required this.db,
    required this.files,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _clock = clock ?? DateTime.now,
       uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final FileStore files;
  final DateTime Function() _clock;
  final Uuid uuid;
  String? _deviceId;

  DateTime now() => _clock().toUtc();

  String newId() => uuid.v4();

  /// Stable per-install id (stamped on outbox ops).
  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    var id = await db.readKv('device_id');
    if (id == null) {
      id = newId();
      await db.writeKv('device_id', id);
    }
    return _deviceId = id;
  }

  // ---------------------------------------------------------------------
  // Outbox

  /// Queues an op. Coalesces an `update` into a not-yet-attempted
  /// `create`/`update` of the same row (payloads merge; the first op's
  /// [baseUpdatedAtKey] is kept so LWW compares against the version the
  /// edit started from).
  Future<void> enqueue({
    required SyncEntity entity,
    required String entityId,
    required SyncOpKind kind,
    required Map<String, Object?> payload,
    String? paperId,
    DateTime? notBefore,
  }) async {
    final at = now();
    await db.transaction(() async {
      if (kind == SyncOpKind.update) {
        final existing =
            await (db.select(db.syncOutbox)
                  ..where(
                    (t) =>
                        t.entity.equals(entity.name) &
                        t.entityId.equals(entityId) &
                        t.kind.isIn([
                          SyncOpKind.create.name,
                          SyncOpKind.update.name,
                        ]) &
                        t.failed.equals(false) &
                        t.attempts.equals(0),
                  )
                  ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                  ..limit(1))
                .getSingleOrNull();
        if (existing != null) {
          final old = asJsonMap(jsonDecode(existing.payload));
          final merged = <String, Object?>{...old, ...payload};
          if (old.containsKey(baseUpdatedAtKey)) {
            merged[baseUpdatedAtKey] = old[baseUpdatedAtKey];
          }
          await (db.update(
            db.syncOutbox,
          )..where((t) => t.id.equals(existing.id))).write(
            SyncOutboxCompanion(
              payload: Value(jsonEncode(merged)),
              localUpdatedAt: Value(at),
            ),
          );
          return;
        }
      }
      await db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: newId(),
              entity: entity.name,
              entityId: entityId,
              paperId: Value(paperId),
              kind: kind.name,
              payload: jsonEncode(payload),
              createdAt: at,
              localUpdatedAt: at,
              deviceId: await deviceId(),
              notBefore: Value(notBefore),
            ),
          );
    });
  }

  Future<List<SyncOpRow>> opsFor(SyncEntity entity, String entityId) =>
      (db.select(db.syncOutbox)
            ..where(
              (t) => t.entity.equals(entity.name) & t.entityId.equals(entityId),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(insertionOrder),
            ]))
          .get();

  Future<void> removeOp(String opId) =>
      (db.delete(db.syncOutbox)..where((t) => t.id.equals(opId))).go();

  Future<void> removeOpsFor(SyncEntity entity, String entityId) =>
      (db.delete(db.syncOutbox)..where(
            (t) => t.entity.equals(entity.name) & t.entityId.equals(entityId),
          ))
          .go();

  // ---------------------------------------------------------------------
  // Shared writes

  /// Inserts [h] as a new local highlight and queues its create.
  Future<Highlight> insertHighlightPendingCreate(Highlight h) async {
    final row = h.copyWith(
      localUpdatedAt: now(),
      syncState: SyncState.pendingCreate,
    );
    await db.transaction(() async {
      await db
          .into(db.highlights)
          .insertOnConflictUpdate(highlightToCompanion(row));
      await enqueue(
        entity: SyncEntity.highlight,
        entityId: row.id,
        kind: SyncOpKind.create,
        payload: row.toSupabaseRow(),
        paperId: row.paperId,
      );
    });
    return row;
  }

  /// Writes a figure note locally (LWW clock = now) and queues the update.
  Future<void> writeFigureNote(String figureId, String? note) async {
    await db.transaction(() async {
      final row = await (db.select(
        db.figureHighlights,
      )..where((t) => t.id.equals(figureId))).getSingleOrNull();
      if (row == null) throw NotFoundException('figure $figureId');
      final state = SyncState.fromName(row.syncState);
      final at = now();
      await (db.update(
        db.figureHighlights,
      )..where((t) => t.id.equals(figureId))).write(
        FigureHighlightsCompanion(
          note: Value(note),
          updatedAt: Value(at),
          syncState: Value(
            state == SyncState.pendingCreate
                ? SyncState.pendingCreate.name
                : SyncState.pendingUpdate.name,
          ),
        ),
      );
      if (state == SyncState.pendingCreate) {
        // The create carries the whole row; just refresh its payload.
        await enqueue(
          entity: SyncEntity.figureHighlight,
          entityId: figureId,
          kind: SyncOpKind.update,
          payload: {'note': note},
          paperId: row.paperId,
        );
      } else {
        await enqueue(
          entity: SyncEntity.figureHighlight,
          entityId: figureId,
          kind: SyncOpKind.update,
          payload: {
            'note': note,
            // The server version this edit is based on (LWW base).
            baseUpdatedAtKey: dateToJson(
              state == SyncState.synced ? row.updatedAt : null,
            ),
          },
          paperId: row.paperId,
        );
      }
    });
  }

  /// Removes a paper and everything hanging off it from this device
  /// (server delete committed, or the server deleted it).
  Future<void> purgePaperLocally(String paperId) async {
    final paper = await (db.select(
      db.papers,
    )..where((t) => t.id.equals(paperId))).getSingleOrNull();
    final figures = await (db.select(
      db.figureHighlights,
    )..where((t) => t.paperId.equals(paperId))).get();
    await db.transaction(() async {
      await (db.delete(db.papers)..where((t) => t.id.equals(paperId))).go();
      await (db.delete(
        db.highlights,
      )..where((t) => t.paperId.equals(paperId))).go();
      await (db.delete(
        db.figureHighlights,
      )..where((t) => t.paperId.equals(paperId))).go();
      await (db.delete(db.notes)..where((t) => t.paperId.equals(paperId))).go();
      await (db.delete(
        db.readingPositions,
      )..where((t) => t.paperId.equals(paperId))).go();
      await (db.delete(
        db.syncOutbox,
      )..where((t) => t.paperId.equals(paperId))).go();
    });
    await files.deleteQuietly(paper?.localFilePath);
    for (final f in figures) {
      await files.deleteQuietly(f.localImagePath);
    }
  }
}
