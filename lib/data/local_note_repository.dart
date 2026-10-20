import 'package:drift/drift.dart';

import '../domain/domain.dart';
import 'db/app_database.dart';
import 'local_store.dart';
import 'mappers.dart';

/// Device-only notes (option A: RPR has no notes table). Never enters the
/// outbox, never counts as pending.
class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository({required this._store});

  final LocalStore _store;

  AppDatabase get _db => _store.db;

  @override
  Stream<List<Note>> watchNotes(String paperId) =>
      (_db.select(_db.notes)
            ..where((t) => t.paperId.equals(paperId) & t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.pageNumber),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch()
          .map((rows) => rows.map(noteFromRow).toList());

  @override
  Stream<List<Note>> watchNotesForHighlight(String highlightId) =>
      (_db.select(_db.notes)
            ..where(
              (t) => t.highlightId.equals(highlightId) & t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch()
          .map((rows) => rows.map(noteFromRow).toList());

  @override
  Future<Note> upsertNote(Note note) async {
    final saved = note.copyWith(
      updatedAt: _store.now(),
      syncState: SyncState.localOnly,
    );
    await _db.into(_db.notes).insertOnConflictUpdate(noteToCompanion(saved));
    return saved;
  }

  @override
  Future<void> deleteNote(String noteId) =>
      (_db.delete(_db.notes)..where((t) => t.id.equals(noteId))).go();

  @override
  Future<void> restoreNote(Note note) =>
      _db.into(_db.notes).insertOnConflictUpdate(noteToCompanion(note));

  @override
  Future<int> countLocalOnlyNotes() async {
    final count = _db.notes.id.count();
    final q = _db.selectOnly(_db.notes)
      ..addColumns([count])
      ..where(_db.notes.deletedAt.isNull());
    return (await q.getSingle()).read(count) ?? 0;
  }

  @override
  Future<String> exportAllAsText() async {
    final notes =
        await (_db.select(_db.notes)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.asc(t.paperId),
                (t) => OrderingTerm.asc(t.pageNumber),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    final papers = {
      for (final p in await _db.select(_db.papers).get()) p.id: p.title,
    };
    final buf = StringBuffer();
    String? current;
    for (final n in notes) {
      if (n.paperId != current) {
        if (current != null) buf.writeln();
        current = n.paperId;
        buf.writeln('# ${papers[n.paperId] ?? n.paperId}');
      }
      final page = n.pageNumber == null ? '' : 'p. ${n.pageNumber}: ';
      if (n.quotedExcerpt != null) buf.writeln('> ${n.quotedExcerpt}');
      buf.writeln('- $page${n.body}');
    }
    return buf.toString();
  }
}
