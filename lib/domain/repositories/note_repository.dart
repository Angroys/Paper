import '../models/note.dart';

/// Device-only notes (text-highlight notes + free page notes) in v1.
abstract interface class NoteRepository {
  Stream<List<Note>> watchNotes(String paperId);

  Stream<List<Note>> watchNotesForHighlight(String highlightId);

  /// Insert or update (sets `updatedAt`).
  Future<Note> upsertNote(Note note);

  Future<void> deleteNote(String noteId);

  /// Undo for [deleteNote].
  Future<void> restoreNote(Note note);

  /// Number of local-only notes (sign-out warning `signOutLocalOnlyBody`).
  Future<int> countLocalOnlyNotes();

  /// Exports all notes as plain text (copy-to-clipboard mitigation).
  Future<String> exportAllAsText();
}
