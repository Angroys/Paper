/// Guest → account merge (optional sign-in).
///
/// Online builds run without an account: everything made on the device is
/// owned by [kGuestUserId] and queued in the outbox like any other write,
/// but the sync engine only pushes while someone is signed in. When a user
/// signs in, [GuestDataMerge.prepareFor] makes the local DB theirs before
/// the first push:
///
/// 1. **Other accounts' rows go.** Papers (with their highlights, notes,
///    reading positions, outbox ops and cached files), highlights and
///    figure highlights owned by any id other than the guest or the new
///    user are removed: someone else's data is never uploaded to this
///    account. This covers "kept on this device" papers of an account that
///    signed out (`signOutProvider(keepLocalData: true)`) when a different
///    account signs in. Their replaced versions and caches go too.
/// 2. **Guest rows are re-owned.** `user_id` becomes the account id and
///    storage paths move from `<guest>/...` to `<user_id>/...` (RPR:
///    `<user_id>/<uuid>.pdf`, `<user_id>/<paper_id>/<figure_id>.png`), in
///    the rows and in the queued op payloads.
/// 3. **Every re-owned row is queued.** Guest writes are queued already;
///    a re-owned row with no op at all gets a `create` op (the row was never
///    on a server: its owner did not exist there). The engine then uploads
///    the PDF to `papers/<user_id>/<uuid>.pdf` and upserts the rows.
///
/// Idempotent: rows keep their client UUIDs (server creates are upserts),
/// a second run finds no guest rows and no guest payloads, and step 3 only
/// queues rows that have no op. Device-only data (notes, colors, reading
/// positions) has no owner column and simply stays.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../data/db/app_database.dart';
import '../data/local_store.dart';
import '../data/mappers.dart';
import '../domain/domain.dart';
import '../domain/models/json.dart';

/// What [GuestDataMerge.prepareFor] changed (for logs and tests).
@immutable
class GuestMergeResult {
  const GuestMergeResult({
    this.adoptedPapers = 0,
    this.adoptedHighlights = 0,
    this.adoptedFigures = 0,
    this.rewrittenOps = 0,
    this.queuedCreates = 0,
    this.removedForeignPapers = 0,
  });

  final int adoptedPapers;
  final int adoptedHighlights;
  final int adoptedFigures;
  final int rewrittenOps;
  final int queuedCreates;
  final int removedForeignPapers;

  bool get changed =>
      adoptedPapers +
          adoptedHighlights +
          adoptedFigures +
          rewrittenOps +
          queuedCreates +
          removedForeignPapers >
      0;

  @override
  String toString() =>
      'GuestMergeResult(papers: $adoptedPapers, highlights: '
      '$adoptedHighlights, figures: $adoptedFigures, ops: $rewrittenOps, '
      'queued: $queuedCreates, removedForeign: $removedForeignPapers)';
}

class GuestDataMerge {
  GuestDataMerge(this._store);

  final LocalStore _store;

  AppDatabase get _db => _store.db;

  static const String _deviceIdKey = 'device_id';

  /// `<guest>/rest` -> `<userId>/rest`; anything else unchanged.
  static String? reownPath(String? path, String userId) {
    const prefix = '$kGuestUserId/';
    if (path == null || !path.startsWith(prefix)) return path;
    return '$userId/${path.substring(prefix.length)}';
  }

  /// Makes the local DB [userId]'s (see the library doc). [previousOwner]
  /// is the account the DB belonged to before (`db_owner_user_id`); when it
  /// is another real account, its caches are dropped as well.
  Future<GuestMergeResult> prepareFor(
    String userId, {
    String? previousOwner,
  }) async {
    assert(!isGuestUserId(userId), 'the guest cannot own the DB');
    bool foreign(String owner) => owner != userId && !isGuestUserId(owner);

    // 1. Other accounts' data.
    final foreignPapers = [
      for (final p in await _db.select(_db.papers).get())
        if (foreign(p.userId)) p.id,
    ];
    for (final id in foreignPapers) {
      await _store.purgePaperLocally(id);
    }
    final strayFigureImages = <String?>[];
    await _db.transaction(() async {
      for (final h in await _db.select(_db.highlights).get()) {
        if (!foreign(h.userId)) continue;
        await (_db.delete(
          _db.highlights,
        )..where((t) => t.id.equals(h.id))).go();
        await _store.removeOpsFor(SyncEntity.highlight, h.id);
      }
      for (final f in await _db.select(_db.figureHighlights).get()) {
        if (!foreign(f.userId)) continue;
        await (_db.delete(
          _db.figureHighlights,
        )..where((t) => t.id.equals(f.id))).go();
        await _store.removeOpsFor(SyncEntity.figureHighlight, f.id);
        strayFigureImages.add(f.localImagePath);
      }
      if (previousOwner != null &&
          previousOwner != userId &&
          !isGuestUserId(previousOwner)) {
        // Another account's replaced versions, sync cursor and AI caches.
        await _db.delete(_db.replacedVersions).go();
        await (_db.delete(
          _db.kv,
        )..where((t) => t.key.equals(_deviceIdKey).not())).go();
      }
    });
    for (final path in strayFigureImages) {
      await _store.files.deleteQuietly(path);
    }

    // 2 + 3. Adopt the guest's rows, in one transaction.
    var papers = 0, highlights = 0, figures = 0, ops = 0, queued = 0;
    await _db.transaction(() async {
      final guestPapers = await (_db.select(
        _db.papers,
      )..where((t) => t.userId.equals(kGuestUserId))).get();
      for (final p in guestPapers) {
        await (_db.update(_db.papers)..where((t) => t.id.equals(p.id))).write(
          PapersCompanion(
            userId: Value(userId),
            storagePath: Value(reownPath(p.storagePath, userId)),
          ),
        );
        papers++;
      }
      final guestHighlights = await (_db.select(
        _db.highlights,
      )..where((t) => t.userId.equals(kGuestUserId))).get();
      for (final h in guestHighlights) {
        await (_db.update(_db.highlights)..where((t) => t.id.equals(h.id)))
            .write(HighlightsCompanion(userId: Value(userId)));
        highlights++;
      }
      final guestFigures = await (_db.select(
        _db.figureHighlights,
      )..where((t) => t.userId.equals(kGuestUserId))).get();
      for (final f in guestFigures) {
        await (_db.update(
          _db.figureHighlights,
        )..where((t) => t.id.equals(f.id))).write(
          FigureHighlightsCompanion(
            userId: Value(userId),
            storagePath: Value(reownPath(f.storagePath, userId)!),
          ),
        );
        figures++;
      }

      // Queued payloads carry user_id / storage_path too.
      for (final op in await _db.select(_db.syncOutbox).get()) {
        final payload = asJsonMap(jsonDecode(op.payload));
        var changed = false;
        if (isGuestUserId(payload['user_id'] as String?)) {
          payload['user_id'] = userId;
          changed = true;
        }
        final path = payload['storage_path'];
        if (path is String) {
          final moved = reownPath(path, userId);
          if (moved != path) {
            payload['storage_path'] = moved;
            changed = true;
          }
        }
        if (!changed) continue;
        await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(op.id)))
            .write(SyncOutboxCompanion(payload: Value(jsonEncode(payload))));
        ops++;
      }

      // Re-owned rows that are not queued at all: queue their create.
      for (final p in guestPapers) {
        if (p.deletedAt != null) continue;
        if ((await _store.opsFor(SyncEntity.paper, p.id)).isNotEmpty) continue;
        final row = await (_db.select(
          _db.papers,
        )..where((t) => t.id.equals(p.id))).getSingle();
        await _markPendingCreate(SyncEntity.paper, p.id);
        await _store.enqueue(
          entity: SyncEntity.paper,
          entityId: p.id,
          kind: SyncOpKind.create,
          payload: paperRowToSupabase(row),
          paperId: p.id,
        );
        queued++;
      }
      for (final h in guestHighlights) {
        if (h.syncState == SyncState.pendingDelete.name) continue;
        if ((await _store.opsFor(SyncEntity.highlight, h.id)).isNotEmpty) {
          continue;
        }
        final row = await (_db.select(
          _db.highlights,
        )..where((t) => t.id.equals(h.id))).getSingle();
        await _markPendingCreate(SyncEntity.highlight, h.id);
        await _store.enqueue(
          entity: SyncEntity.highlight,
          entityId: h.id,
          kind: SyncOpKind.create,
          payload: highlightFromRow(row).toSupabaseRow(),
          paperId: h.paperId,
        );
        queued++;
      }
      for (final f in guestFigures) {
        if (f.syncState == SyncState.pendingDelete.name) continue;
        if ((await _store.opsFor(
          SyncEntity.figureHighlight,
          f.id,
        )).isNotEmpty) {
          continue;
        }
        final row = await (_db.select(
          _db.figureHighlights,
        )..where((t) => t.id.equals(f.id))).getSingle();
        await _markPendingCreate(SyncEntity.figureHighlight, f.id);
        await _store.enqueue(
          entity: SyncEntity.figureHighlight,
          entityId: f.id,
          kind: SyncOpKind.create,
          payload: figureFromRow(row).toSupabaseRow(),
          paperId: f.paperId,
        );
        queued++;
      }
    });

    return GuestMergeResult(
      adoptedPapers: papers,
      adoptedHighlights: highlights,
      adoptedFigures: figures,
      rewrittenOps: ops,
      queuedCreates: queued,
      removedForeignPapers: foreignPapers.length,
    );
  }

  /// Sign-out with "keep on this device" (the default): the account's
  /// papers stay readable for the guest. Papers that are only in the cloud
  /// (no PDF on the device and nothing queued) cannot be opened signed out,
  /// so they are removed; they come back when the account signs in again.
  /// Returns how many were removed.
  Future<int> keepDeviceCopiesForGuest() async {
    final drop = <String>[];
    for (final p in await _db.select(_db.papers).get()) {
      if (isGuestUserId(p.userId)) continue;
      final file = p.localFilePath;
      if (file != null && await _store.files.exists(file)) continue;
      if ((await _store.opsFor(SyncEntity.paper, p.id)).isNotEmpty) continue;
      drop.add(p.id);
    }
    for (final id in drop) {
      await _store.purgePaperLocally(id);
    }
    return drop.length;
  }

  Future<void> _markPendingCreate(SyncEntity entity, String id) {
    final state = Value(SyncState.pendingCreate.name);
    switch (entity) {
      case SyncEntity.paper:
        return (_db.update(_db.papers)..where((t) => t.id.equals(id))).write(
          PapersCompanion(syncState: state),
        );
      case SyncEntity.highlight:
        return (_db.update(_db.highlights)..where((t) => t.id.equals(id)))
            .write(HighlightsCompanion(syncState: state));
      case SyncEntity.figureHighlight:
        return (_db.update(_db.figureHighlights)..where((t) => t.id.equals(id)))
            .write(FigureHighlightsCompanion(syncState: state));
    }
  }
}
