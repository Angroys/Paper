import 'dart:typed_data';

/// Name of RPR's private PDF bucket (`src/lib/papers/bucket.ts`).
/// Objects live at `<user_id>/<uuid>.pdf`.
const String papersBucket = 'papers';

/// Name of RPR's private figure-crop bucket (`src/lib/figures/types.ts`).
/// Objects live at `<user_id>/<paper_id>/<figure_id>.png`.
const String figuresBucket = 'figures';

/// `<user_id>/<uuid>.pdf` (RPR `buildStoragePath`).
String paperStoragePath(String userId, String objectId) =>
    '$userId/$objectId.pdf';

/// `<user_id>/<paper_id>/<figure_id>.png` (RPR `figureStoragePath`).
String figureStoragePath(String userId, String paperId, String figureId) =>
    '$userId/$paperId/$figureId.png';

/// Thin boundary around Supabase (PostgREST + Storage) and the paper.college
/// API. Rows are Supabase snake_case maps. Every method throws only
/// `PaperException`s (lib/domain/errors.dart): `OfflineException`,
/// `AuthExpiredException`, `NotFoundException`, `ServerException`.
///
/// RLS scopes every query to the signed-in user, so "fetch all" means
/// "all of mine". Repositories and the sync engine only talk to this
/// interface; tests use an in-memory fake.
abstract interface class RemoteDataSource {
  Future<List<Map<String, Object?>>> fetchPapers();

  /// Insert-or-update by id (idempotent replays).
  Future<Map<String, Object?>> upsertPaper(Map<String, Object?> row);

  /// Partial update. Throws `NotFoundException` when the row is gone.
  Future<void> updatePaper(String id, Map<String, Object?> fields);

  /// Deletes the row and its storage object. Missing row is not an error.
  Future<void> deletePaper(String id);

  Future<List<Map<String, Object?>>> fetchHighlights();

  /// Insert, ignoring a duplicate id (idempotent replays).
  Future<void> insertHighlight(Map<String, Object?> row);

  Future<void> deleteHighlight(String id);

  Future<List<Map<String, Object?>>> fetchFigureHighlights();

  Future<Map<String, Object?>?> fetchFigureHighlight(String id);

  Future<Map<String, Object?>> upsertFigureHighlight(Map<String, Object?> row);

  /// Updates `note`; the server stamps `updated_at`. Returns the new row.
  /// Throws `NotFoundException` when the row is gone.
  Future<Map<String, Object?>> updateFigureNote(String id, String? note);

  Future<void> deleteFigureHighlight(String id);

  /// Uploads bytes (upsert) to [bucket] at [path].
  Future<void> uploadObject(
    String bucket,
    String path,
    Uint8List bytes, {
    required String contentType,
  });

  /// Downloads an object, reporting 0..1 progress when the size is known.
  Future<Uint8List> downloadObject(
    String bucket,
    String path, {
    void Function(double progress)? onProgress,
  });

  /// `POST /api/papers/import` on the paper.college API. Returns the
  /// inserted `papers` row. Throws `InvalidPdfException` (415),
  /// `FileTooLargeException` (413), `ServerException` otherwise.
  Future<Map<String, Object?>> importPaperFromUrl(Uri url);
}
