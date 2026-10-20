import 'dart:io';

import 'package:drift/drift.dart';

import '../domain/domain.dart';
import '../domain/models/json.dart';
import 'db/app_database.dart';
import 'local_store.dart';
import 'mappers.dart';
import 'remote/remote_data_source.dart';

/// Local-first [HighlightRepository] (option A, design/specs/flows.md):
/// text highlights sync create/delete only, colour is device-only, figure
/// notes sync last-write-wins on `updated_at`.
class LocalHighlightRepository implements HighlightRepository {
  LocalHighlightRepository({
    required this._store,
    required String? Function() currentUserId,
  }) : _userId = currentUserId;

  final LocalStore _store;
  final String? Function() _userId;

  AppDatabase get _db => _store.db;

  String _owner(String given) {
    if (given.isNotEmpty) return given;
    final id = _userId();
    if (id == null) throw const AuthExpiredException('Not signed in');
    return id;
  }

  @override
  Stream<List<Highlight>> watchHighlights(String paperId) =>
      (_db.select(_db.highlights)
            ..where(
              (t) =>
                  t.paperId.equals(paperId) &
                  t.syncState.equals(SyncState.pendingDelete.name).not(),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.pageNumber),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch()
          .map((rows) => rows.map(highlightFromRow).toList());

  @override
  Future<Highlight> createHighlight(Highlight highlight) {
    final owner = _owner(highlight.userId);
    final h = owner == highlight.userId
        ? highlight
        : Highlight.fromJson({...highlight.toJson(), 'user_id': owner});
    return _store.insertHighlightPendingCreate(h);
  }

  @override
  Future<void> updateColor(String highlightId, HighlightColor color) =>
      (_db.update(
        _db.highlights,
      )..where((t) => t.id.equals(highlightId))).write(
        HighlightsCompanion(
          color: Value(color.name),
          localUpdatedAt: Value(_store.now()),
        ),
      );

  @override
  Future<void> deleteHighlight(String highlightId) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.highlights,
      )..where((t) => t.id.equals(highlightId))).getSingleOrNull();
      if (row == null) return;
      await (_db.update(
        _db.highlights,
      )..where((t) => t.id.equals(highlightId))).write(
        HighlightsCompanion(
          syncState: Value(SyncState.pendingDelete.name),
          localUpdatedAt: Value(_store.now()),
        ),
      );
      // A never-pushed highlight is resolved locally by the sync engine
      // (create + delete cancel out).
      await _store.enqueue(
        entity: SyncEntity.highlight,
        entityId: highlightId,
        kind: SyncOpKind.delete,
        payload: const {},
        paperId: row.paperId,
      );
    });
  }

  @override
  Future<void> restoreHighlight(Highlight highlight) async {
    await _db.transaction(() async {
      final ops = await _store.opsFor(SyncEntity.highlight, highlight.id);
      final pendingDelete = ops.where(
        (o) => o.kind == SyncOpKind.delete.name && !o.failed,
      );
      final row = await (_db.select(
        _db.highlights,
      )..where((t) => t.id.equals(highlight.id))).getSingleOrNull();
      if (row != null && pendingDelete.isNotEmpty) {
        // Delete not pushed yet: cancel it.
        for (final op in pendingDelete) {
          await _store.removeOp(op.id);
        }
        final stillCreating = ops.any((o) => o.kind == SyncOpKind.create.name);
        await (_db.update(
          _db.highlights,
        )..where((t) => t.id.equals(highlight.id))).write(
          HighlightsCompanion(
            syncState: Value(
              stillCreating
                  ? SyncState.pendingCreate.name
                  : SyncState.synced.name,
            ),
            color: Value(highlight.color.name),
          ),
        );
        return;
      }
      // Already deleted on the server: create it again (same id).
      await _store.insertHighlightPendingCreate(highlight);
    });
  }

  @override
  Stream<List<FigureHighlight>> watchFigureHighlights(String paperId) =>
      (_db.select(_db.figureHighlights)
            ..where(
              (t) =>
                  t.paperId.equals(paperId) &
                  t.syncState.equals(SyncState.pendingDelete.name).not(),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.pageNumber),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch()
          .map((rows) => rows.map(figureFromRow).toList());

  @override
  Future<FigureHighlight> createFigureHighlight(
    FigureHighlight figure, {
    required Uint8List pngBytes,
  }) async {
    final owner = _owner(figure.userId);
    final imagePath = await _store.files.figurePath(figure.id);
    try {
      await File(imagePath).writeAsBytes(pngBytes, flush: true);
    } on FileSystemException catch (e) {
      throw StorageException(e.message);
    }
    final now = _store.now();
    final f = FigureHighlight.fromJson({
      ...figure.toJson(),
      'user_id': owner,
      'storage_path': figureStoragePath(owner, figure.paperId, figure.id),
      'updated_at': dateToJson(now),
      'local_image_path': imagePath,
      'sync_state': SyncState.pendingCreate.name,
    });
    await _db.transaction(() async {
      await _db
          .into(_db.figureHighlights)
          .insertOnConflictUpdate(figureToCompanion(f));
      await _store.enqueue(
        entity: SyncEntity.figureHighlight,
        entityId: f.id,
        kind: SyncOpKind.create,
        payload: f.toSupabaseRow(),
        paperId: f.paperId,
      );
    });
    return f;
  }

  @override
  Future<void> updateFigureNote(String figureHighlightId, String? note) =>
      _store.writeFigureNote(figureHighlightId, note);

  @override
  Future<void> deleteFigureHighlight(String figureHighlightId) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.figureHighlights,
      )..where((t) => t.id.equals(figureHighlightId))).getSingleOrNull();
      if (row == null) return;
      await (_db.update(
        _db.figureHighlights,
      )..where((t) => t.id.equals(figureHighlightId))).write(
        FigureHighlightsCompanion(
          syncState: Value(SyncState.pendingDelete.name),
        ),
      );
      await _store.enqueue(
        entity: SyncEntity.figureHighlight,
        entityId: figureHighlightId,
        kind: SyncOpKind.delete,
        payload: const {},
        paperId: row.paperId,
      );
    });
  }
}
