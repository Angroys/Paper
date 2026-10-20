import '../models/paper.dart';
import '../models/reading_position.dart';

enum PaperSort { recentlyOpened, recentlyAdded, title }

/// Library: local SQLite mirror of `papers` + downloaded PDFs on disk.
/// Writes are local-first (optimistic) and queue a `SyncOp`.
abstract interface class PaperRepository {
  /// Library list, local DB first; emits again on every change.
  Stream<List<Paper>> watchPapers({
    String query = '',
    PaperSort sort = PaperSort.recentlyOpened,
  });

  Stream<Paper?> watchPaper(String paperId);

  Future<Paper?> getPaper(String paperId);

  /// Pulls the server library into the local DB (no-op offline).
  Future<void> refresh();

  /// Imports a PDF by URL (needs network). Throws `OfflineException`,
  /// `InvalidPdfException`, `FileTooLargeException`.
  Future<Paper> importFromUrl(Uri url);

  /// Imports a local PDF file. Offline: saved locally, upload queued.
  Future<Paper> importFile(String filePath, {String? fileName});

  Future<void> rename(String paperId, String title);

  /// Soft-deletes (hidden immediately, undo window); the server delete is
  /// queued. Also removes the paper's local-only notes and colours.
  Future<void> delete(String paperId);

  /// Undo for [delete] inside the undo window.
  Future<void> undoDelete(String paperId);

  Future<void> setRead(String paperId, {required bool read});

  Future<void> dismissMatchNotice(String paperId);

  /// Returns a local file path for the PDF, downloading it if needed.
  /// [onProgress] gets 0..1. Throws `OfflineException` if not cached.
  Future<String> ensureLocalFile(
    String paperId, {
    void Function(double progress)? onProgress,
  });

  /// Frees the cached PDF (paper stays in the library).
  Future<void> removeDownload(String paperId);

  /// Device-only; callers debounce (1 s).
  Future<void> saveReadingPosition(String paperId, ReadingPosition position);

  Future<void> markOpened(String paperId);
}
